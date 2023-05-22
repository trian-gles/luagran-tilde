/**
	@file
	luagran~

*/

#include "m_pd.h"
#include <stdlib.h>
#include <stdbool.h>

#include "lua/lauxlib.h"
#include "lua/lua.h"
#include "lua/lualib.h"

#define MAXGRAINS 1000
#define MIDC_OFFSET (261.62556530059868 / 256.0)
#define M_LN2	0.69314718055994529
#define DEFAULT_TABLE_SIZE 1024

static t_class *s_luagran_class;

typedef struct Grain {
	float waveSampInc; 
	float ampSampInc; 
	float wavePhase; 
	float ampPhase; 
	int dur; 
	float panR; 
	float panL; 
	int currTime; 
	bool isplaying;
	} Grain;

typedef struct _luagran {
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
} t_luagran;




void *luagran_new(t_symbol *s);
void luagran_free(t_luagran *x);
void luagran_start(t_luagran *x);
void luagran_stop(t_luagran *x);
t_int *luagran_perform(t_int *w);
void luagran_dsp(t_luagran *x, t_signal **sp);
void luagran_anything(t_luagran *x, t_symbol *s, long argc, t_atom *argv);

 

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





void luagran_setup(void *r)
{
	t_class* c = class_new("luagran~", (t_newmethod)luagran_new, (t_method)luagran_free, sizeof(t_luagran), CLASS_DEFAULT, A_DEFSYMBOL, 0);

	class_addmethod(c, (t_method)luagran_dsp64,		gensym("dsp64"),	A_CANT, 0);
	class_addmethod(c, (t_method)luagran_start,		gensym("start"), 0);
	class_addmethod(c, (t_method)luagran_stop,		gensym("stop"), 0);
	class_addanything(t_class *c, (t_method)luagran_anything);
	s_luagran_class = c;
}

/* Args:
		p0: script name
	*/
	
// will eventually need to handle for buffers with more than one channel
void *luagran_new(t_symbol *s)
{
	t_luagran *x = (t_luagran *)pd_new(s_luagran_class);
	
	
	//outlets
	x_out_l = outlet_new(&x->x_obj, &s_signal);		// audio outlet l
	x_out_r = outlet_new(&x->x_obj, &s_signal);		// audio outlet r
	
	
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
	
	newGrainCounter = 0;
	running = false;


	//Setup Lua
	
	
	//Use default wavetables
	luagran_usesine(x);
	luagran_usehanning(x);


	return (x);
}

void luagran_usesine(t_luagran* x){
	
	x->extern_wave = false;
	for (size_t i = 0; i < DEFAULT_TABLE_SIZE; i++){
		x->sineTable[i] = sin(3.141596 * 2 * ((float) i / DEFAULT_TABLE_SIZE));
	}
	x->w_len = DEFAULT_TABLE_SIZE;
}

void luagran_usehanning(t_luagran* x){
	
	x->extern_env = false;
	for (size_t i = 0; i < DEFAULT_TABLE_SIZE; i++){
		x->hanningTable[i] = 0.5 * (1 - cos(3.141596 * 2 * ((float) i / DEFAULT_TABLE_SIZE)));
		}
	x->w_envlen = DEFAULT_TABLE_SIZE;
}




void luagran_free(t_luagran *x)
{
	outlet_free(x->x_out_l);
	outlet_free(x->x_out_r);
	lua_close(x->L);
}

void luagran_anything(t_luagran *x, t_symbol *s, long argc, t_atom *argv)
{
    long i;
    t_atom *ap;
	
	lua_getglobal(x->L, "granmodule");
	lua_getfield(x->L, -1, "update");
	
    for (i = 0, ap = argv; i < argc; i++, ap++) {
        switch (atom_gettype(ap)) {
            case A_LONG:
                lua_pushnumber(x->L, (double)atom_getlong(ap));
                break;
            case A_FLOAT:
                lua_pushnumber(x->L, (double)atom_getfloat(ap));
                break;
            case A_SYM:
				lua_pushstring(x->L, atom_getsym(ap)->s_name);
                break;
            default:
                post("%ld: unknown atom type (%ld)", i+1, atom_gettype(ap));
                break;
        }
    }
	lua_call(x->L, argc, 0);
}




////
// START AND STOP MSGS
////
void luagran_start(t_luagran *x){
	if (!buffer_ref_exists(x->w_buf) || !buffer_ref_exists(x->w_env))
	{
		error("Make sure you've configured a wavetable buffer and envelope buffer!");
		defer((t_object*)x, (method)luagran_setbuffers, NULL, 0, NULL);
	}
		
	else
		x->running = true;
}

void luagran_stop(t_luagran *x){
	x->running = false;
}


void luagran_new_grain(t_luagran *x, Grain *grain){
	lua_getglobal(x->L, "granmodule");
	lua_getfield(x->L, -1, "generate");
    lua_call(x->L, 0, 5);
	
	double rate = lua_tonumber(L, -5);
    double dur = lua_tonumber(L, -4);
	double freq = lua_tonumber(L, -3);
	double amp = lua_tonumber(L, -2);
	double pan = lua_tonumber(L, -1);
	lua_pop(L, 5);
	
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
	
	x->newGrainCounter = (float) rate * sr / 1000;
	
}

void luagran_reset_grain_rate(t_luagran *x){
	x->newGrainCounter = (int)round((double)sys_getsr() * prob(x->grainRateVarLow, x->grainRateVarMid, x->grainRateVarHigh, x->grainRateVarTight));
}


// rewrite
t_int *luagran_perform(t_int *w)
{
	t_xfade_tilde *x = (t_xfade_tilde *)(w[1]);
	t_sample    *l_out =      (t_sample *)(w[2]);
	t_sample    *r_out =      (t_sample *)(w[3]);
	int            n =             (int)(w[4]);
	
	b = x->sineTable;
	e = x->hanningTable;
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
					float grainAmp = oscili(1, currGrain->ampSampInc, e, x->w_envlen, &((*currGrain).ampPhase));
					float grainOut = oscili(grainAmp ,currGrain->waveSampInc, b, x->w_len, &((*currGrain).wavePhase));
					*l_out += (grainOut * (double)currGrain->panL);
					*r_out += (grainOut * (double)currGrain->panR);
				}
			}
			// this is not an else statement so a grain can be potentially stopped and restarted on the same frame

			if ((x->newGrainCounter <= 0) && !currGrain->isplaying)
			{
				luagran_reset_grain_rate(x);
				if (x->newGrainCounter > 0) // we don't allow two grains to be create on the same frame
					{luagran_new_grain(x, currGrain);}
				else
					{x->newGrainCounter = 1;}

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
}

// adjust for the appropriate number of inlets and outlets (2 out, no in)
void luagran_dsp(t_luagran *x, t_signal **sp)
{
	dsp_add(luagran_perform, 4, x,
          sp[0]->s_vec, sp[1]->s_vec, sp[0]->s_n);
}
