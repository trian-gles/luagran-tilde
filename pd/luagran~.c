/**
	@file
	luagran_tilde~

*/

#include "m_pd.h"
#include <stdlib.h>
#include <stdbool.h>
#include <math.h>
#include <string.h>

#include "lauxlib.h"
#include "lua.h"
#include "lualib.h"

#define MAXGRAINS 1000
#define MIDC_OFFSET (261.62556530059868 / 256.0)
#define DEFAULT_TABLE_SIZE 1024

#ifndef M_LN2
#define M_LN2 0.69314718056
#endif

static t_class *luagran_tilde_class;

typedef struct Grain {
	float waveSampInc; 
	float ampSampInc; 
	float wavePhase; 
	float ampPhase; 
	int dur; 
	float amp;
	float panR; 
	float panL; 
	int currTime; 
	bool isplaying;
	} Grain;

typedef struct _luagran_tilde {
	t_object w_obj;
	
	float sineTable[DEFAULT_TABLE_SIZE];
	float hanningTable[DEFAULT_TABLE_SIZE];
	
	lua_State *L;
	
	bool extern_wave;
	bool extern_env;
	bool running;
	Grain grains[MAXGRAINS];
	
	long w_len;
	long w_envlen;
	
	int newGrainCounter;
	
	
	t_outlet* x_out_l;
	t_outlet* x_out_r;
} t_luagran_tilde;




void *luagran_tilde_new(t_symbol *s);
void luagran_tilde_free(t_luagran_tilde *x);
void luagran_tilde_start(t_luagran_tilde *x);
void luagran_tilde_stop(t_luagran_tilde *x);
t_int *luagran_tilde_perform(t_int *w);
void luagran_tilde_dsp(t_luagran_tilde *x, t_signal **sp);
void luagran_tilde_anything(t_luagran_tilde *x, t_symbol *s, long argc, t_atom *argv);
void luagran_tilde_doread(t_luagran_tilde *x, t_symbol *s);
void luagran_tilde_usesine(t_luagran_tilde *x);
void luagran_tilde_usehanning(t_luagran_tilde *x);

 

double rrand() 
{
	double min = -1;
	double max = 1;
    double range = (max - min); 
    double div = RAND_MAX / range;
    return min + (rand() / div);
}

// Taken from RTCMIX code 
// https://github.com/RTcmix/RTcmix/blob/1b04fd3f121a1c65743fde8ea37eb5d65f2cf35c/genlib/pitchconv.c
double octcps(double cps)
{
	return log(cps / MIDC_OFFSET) / M_LN2;
}

double cpsoct(double oct)
{
	return pow(2.0, oct) * MIDC_OFFSET;
}

float oscili(float amp, float si, float *farray, int len, float *phs)
{
	register int i =  *phs;        
	register int k =  (i + 1) % len;  
	float frac = *phs  - i;      
	*phs += si;                 
	while(*phs >= len)
		*phs -= len;       
	return((*(farray+i) + (*(farray+k) - *(farray+i)) *
					   frac) * amp);
}

int error_handler(lua_State *L) {
  // Push a stack trace string onto the stack.
  // This augmented string will effectively replace the simpler
  // error message that comes directly from the Lua error.
  luaL_traceback(L, L, lua_tostring(L, -1), 1);
  return 1;
}

void set_lua_path(lua_State* L, const char* path)
{
	lua_getglobal( L, "package" );
    lua_getfield( L, -1, "path" ); // get field "path" from table at top of stack (-1)
	char new_path[MAXPDSTRING];

    strcpy(new_path, lua_tostring( L, -1 )); // grab path string from top of stack
	strcat(new_path, ";");
	strcat(new_path, path);
	strcat(new_path, "/?.lua");

    lua_pop( L, 1 ); // get rid of the string on the stack we just pushed on line 5
    lua_pushstring( L, new_path); // push the new one
    lua_setfield( L, -2, "path" ); // set the field "path" in table at -2 with value at top of stack
    lua_pop( L, 1 ); // get rid of package table from top of stack
}

int lua_post(lua_State *L){
	const char* str = lua_tostring(L, 1);
	post(str);
	return 0;
}





void luagran_tilde_setup(void)
{
	t_class* c = class_new(gensym("luagran~"), (t_newmethod)luagran_tilde_new, (t_method)luagran_tilde_free, sizeof(t_luagran_tilde), CLASS_DEFAULT, A_DEFSYMBOL, 0);

	class_addmethod(c, (t_method)luagran_tilde_dsp,		gensym("dsp"),	A_CANT, 0);
	class_addmethod(c, (t_method)luagran_tilde_start,		gensym("start"), 0);
	class_addmethod(c, (t_method)luagran_tilde_stop,		gensym("stop"), 0);
	class_addanything(c, (t_method)luagran_tilde_anything);
	luagran_tilde_class = c;
}

/* Args:
		p0: script name
	*/
	
// will eventually need to handle for buffers with more than one channel
void *luagran_tilde_new(t_symbol *s)
{
	t_luagran_tilde *x = (t_luagran_tilde *)pd_new(luagran_tilde_class);
	
	
	//outlets
	x->x_out_l = outlet_new(&x->w_obj, &s_signal);		// audio outlet l
	x->x_out_r = outlet_new(&x->w_obj, &s_signal);		// audio outlet r
	
	
	// Setup Grains
	for (size_t i = 0; i < MAXGRAINS; i++){
        x->grains[i] = (Grain){.waveSampInc=0, 
        	.ampSampInc=0, 
        	.wavePhase=0, 
        	.ampPhase=0, 
        	.dur=0, 
        	.panR=0, 
        	.panL=0, 
        	.currTime=0, 
        	.isplaying=false };
    } 
	
	x->newGrainCounter = 0;
	x->running = false;


	//Setup Lua
	x->L = luaL_newstate();
	luaL_openlibs(x->L);
	luagran_tilde_doread(x, s);
	
	//Use default wavetables
	luagran_tilde_usesine(x);
	luagran_tilde_usehanning(x);

	return ((void *)x);
}

void luagran_tilde_doread(t_luagran_tilde *x, t_symbol *s){
	char searchfile[MAXPDSTRING];

	strcpy(searchfile, s->s_name);
	char outpath[MAXPDSTRING];
	//char* outname;


	


	const char *dirname = canvas_getdir(canvas_getcurrent())->s_name;
	sprintf(outpath, "%s/%s", dirname, searchfile);
	//int fd = open_via_path(dirname, searchfile, "", outpath, &outname, MAXPDSTRING, 1);
	
	//if (fd < 0){
	//	pd_error(x, "%s: error finding file", searchfile);
    //    return;
	//}
	set_lua_path(x->L, dirname);
	post("Attempting to open file %s", outpath);
	if(luaL_dofile(x->L, outpath) != 0){ // +1, 1
		pd_error(x, "%s: error opening file", outpath);
        return;
	}
	lua_setglobal(x->L, "granmodule");  // -1, 0
    lua_settop(x->L, 0);
	
	lua_pushcfunction(x->L, lua_post);
	lua_setglobal(x->L, "post");

	lua_pushcfunction(x->L, error_handler);
	lua_getglobal(x->L, "granmodule");
	lua_getfield(x->L, -1, "init");
	
    int status = lua_pcall(x->L, 0, 0, -3);
	if (status != LUA_OK){
		pd_error(x, lua_tostring(x->L, -1));
	}
	lua_settop(x->L, 0);
}



void luagran_tilde_usesine(t_luagran_tilde* x){
	
	x->extern_wave = false;
	for (size_t i = 0; i < DEFAULT_TABLE_SIZE; i++){
		x->sineTable[i] = sin(3.141596 * 2 * ((float) i / DEFAULT_TABLE_SIZE));
	}
	x->w_len = DEFAULT_TABLE_SIZE;
}

void luagran_tilde_usehanning(t_luagran_tilde* x){
	
	x->extern_env = false;
	for (size_t i = 0; i < DEFAULT_TABLE_SIZE; i++){
		x->hanningTable[i] = 0.5 * (1 - cos(3.141596 * 2 * ((float) i / DEFAULT_TABLE_SIZE)));
		}
	x->w_envlen = DEFAULT_TABLE_SIZE;
}




void luagran_tilde_free(t_luagran_tilde *x)
{
	outlet_free(x->x_out_l);
	outlet_free(x->x_out_r);
	lua_close(x->L);
}

void luagran_tilde_anything(t_luagran_tilde *x, t_symbol *s, long argc, t_atom *argv)
{
    long i;
    t_atom *ap;
	post("Update with symbol %s", s);

	lua_pushcfunction(x->L, error_handler);
	lua_getglobal(x->L, "granmodule");
	lua_getfield(x->L, -1, "update");
	
    for (i = 0, ap = argv; i < argc; i++, ap++) {
        lua_pushnumber(x->L, (double)atom_getfloat(ap));
    }

	int status = lua_pcall(x->L, argc, 0, -3 - argc);
	if (status != LUA_OK){
		pd_error(x, lua_tostring(x->L, -1));
	}
	lua_settop(x->L, 0);
}




////
// START AND STOP MSGS
////
void luagran_tilde_start(t_luagran_tilde *x){
	x->running = true;
}

void luagran_tilde_stop(t_luagran_tilde *x){
	x->running = false;
}


void luagran_tilde_new_grain(t_luagran_tilde *x, Grain *grain){

	
	//lua_pushcfunction(x->L, error_handler);
	lua_getglobal(x->L, "granmodule");
	lua_getfield(x->L, -1, "generate");
	
    lua_call(x->L, 0, 5);

	

	double rate = lua_tonumber(x->L, -5);
    double dur = lua_tonumber(x->L, -4);
	double freq = lua_tonumber(x->L, -3);
	double amp = lua_tonumber(x->L, -2);
	double pan = lua_tonumber(x->L, -1);
	lua_settop(x->L, 0);
	
	float sr = sys_getsr();
	
	float grainDurSamps = (float) dur * sr / 1000;
	
	grain->waveSampInc = x->w_len * freq / sr;
	grain->ampSampInc = ((float)x->w_envlen) / grainDurSamps;
	grain->currTime = 0;
	grain->isplaying = true;
	grain->wavePhase = 0;
	grain->ampPhase = 0;
	grain->panR = pan;
	grain->panL = 1 - pan; // separating these in RAM means fewer sample rate calculations
	grain->dur = (int)round(grainDurSamps);
	grain->amp = amp;
	
	x->newGrainCounter = (float) rate * sr / 1000;
	
}


// rewrite
t_int *luagran_tilde_perform(t_int *w)
{
	t_luagran_tilde *x = (t_luagran_tilde *)(w[1]);
	t_sample    *l_out =      (t_sample *)(w[2]);
	t_sample    *r_out =      (t_sample *)(w[3]);
	int            n =             (int)(w[4]);
	
	float* b = x->sineTable;
	float* e = x->hanningTable;
	if (!b || !e || !x->running)
	{
		//post("DSP failure");
		goto zero;
	}
		
	
	while (n--){
		for (size_t j = 0; j < MAXGRAINS; j++){
			Grain* currGrain = &x->grains[j];
			
			if (currGrain->isplaying)
			{
				if (++(*currGrain).currTime > currGrain->dur)
				{
					currGrain->isplaying = false;
				}
				else
				{
					// should include an interpolation option at some point
					float grainAmp = currGrain->amp * oscili(1, currGrain->ampSampInc, e, x->w_envlen, &((*currGrain).ampPhase));
					float grainOut = oscili(grainAmp ,currGrain->waveSampInc, b, x->w_len, &((*currGrain).wavePhase));
					
					*l_out += (grainOut * (double)currGrain->panL);
					*r_out += (grainOut * (double)currGrain->panR);
				}
			}
			// this is not an else statement so a grain can be potentially stopped and restarted on the same frame

			if ((x->newGrainCounter <= 0) && !currGrain->isplaying)
			{
				luagran_tilde_new_grain(x, currGrain);
			}
		}
		l_out++;
		r_out++;
		x->newGrainCounter--;
	}
	
	// if all current grains are occupied, we skip this request for a new grain
	if (x->newGrainCounter <= 0)
	{
		x->newGrainCounter = 1;
	}
	
	return w+5;
zero:
	while (n--) {
			
		*l_out++ = 0.;
		*r_out++ = 0.;
	}
	return w+5;
}

// adjust for the appropriate number of inlets and outlets (2 out, no in)
void luagran_tilde_dsp(t_luagran_tilde *x, t_signal **sp)
{
	dsp_add(luagran_tilde_perform, 4, x,
          sp[0]->s_vec, sp[1]->s_vec, sp[0]->s_n);
}
