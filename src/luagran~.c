/**
	@file
	luagran~ - a granulation algorithm designed by Mara Helmuth, rewritten and ported to Max by Kieran McAuliffe

*/

#include "ext.h"
#include "z_dsp.h"
#include "math.h"
#include "ext_buffer.h"
#include "ext_atomic.h"
#include "ext_obex.h"
#include <stdlib.h>
#include <stdbool.h>

#include "lua/lauxlib.h"
#include "lua/lua.h"
#include "lua/lualib.h"

#define MAXGRAINS 1000
#define MIDC_OFFSET (261.62556530059868 / 256.0)
#define M_LN2	0.69314718055994529



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
	t_pxobject w_obj;
	t_buffer_ref *w_buf;
	t_buffer_ref *w_env;
	t_symbol *w_name;
	t_symbol *w_envname;
	
	lua_State *L;
	
	t_bool running;
	Grain grains[MAXGRAINS];
	
	long w_len;
	long w_envlen;
	
	int newGrainCounter;
	
	short w_connected[2];
} t_luagran;




void *luagran_new(t_symbol *s,  long argc, t_atom *argv);
void luagran_free(t_luagran *x);
t_max_err luagran_notify(t_luagran *x, t_symbol *s, t_symbol *msg, void *sender, void *data);
void luagran_assist(t_luagran *x, void *b, long m, long a, char *s);
void luagran_start(t_luagran *x);
void luagran_stop(t_luagran *x);
void luagran_perform64(t_luagran *x, t_object *dsp64, double **ins, long numins, double **outs, long numouts, long sampleframes, long flags, void *userparam);
void luagran_dsp64(t_luagran *x, t_object *dsp64, short *count, double samplerate, long maxvectorsize, long flags);
void luagran_anything(t_luagran *x, t_symbol *s, long argc, t_atom *argv);
void luagran_set(t_luagran* x, t_symbol* s, long argc, t_atom* argv);

 

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


static t_class *s_luagran_class;


void ext_main(void *r)
{
	t_class *c = class_new("luagran~", (method)luagran_new, (method)luagran_free, sizeof(t_luagran), NULL, A_GIMME, 0);

	class_addmethod(c, (method)luagran_dsp64,		"dsp64",	A_CANT, 0);
	class_addmethod(c, (method)luagran_start,		"start", 0);
	class_addmethod(c, (method)luagran_stop,		"stop", 0);
	
	class_addmethod(c, (method)luagran_notify,		"notify",	A_CANT, 0);
	class_addmethod(c, (method)luagran_set, "set", A_GIMME, 0);
	
	class_addmethod(c, (method)luagran_assist,		"assist",	A_CANT, 0);
	
	class_addmethod(c, (method)luagran_anything, "anything", A_GIMME, 0);

	class_dspinit(c);
	class_register(CLASS_BOX, c);
	s_luagran_class = c;

}
/*
	Inlets:
	0 : start, stop, grainrate, graindur, freq, pan
	
*/

/* Args:
		p0: wavetable
		p1: grainEnv
		p2: script name
	*/
	
// will eventually need to handle for buffers with more than one channel
void *luagran_new(t_symbol *s,  long argc, t_atom *argv)
{
	t_luagran *x = (t_luagran *)object_alloc(s_luagran_class);
	t_symbol *buf=0;
	t_symbol *env=0;

	dsp_setup((t_pxobject *)x,0);
	buf = atom_getsymarg(0,argc,argv);
	env = atom_getsymarg(1,argc,argv);

	x->w_name = buf;
	x->w_envname = env;
	
	
	//outlets
	outlet_new((t_object *)x, "signal");		// audio outlet l
	outlet_new((t_object *)x, "signal");		// audio outlet r
	
	
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


	//Setup Lua
	x->L = luaL_newstate();
	luaL_openlibs(x->L);
	t_symbol *s = atom_getsymarg(2,argc,argv);
	char ps[MAX_PATH_CHARS];
	strcpy(ps,s->s_name);
	
	luaL_dofile(x->L, str);
	lua_setglobal(x->L, "granmodule");
    lua_settop(x->L, 0);
	
	lua_getglobal(x->L, "granmodule");
	
	lua_getfield(x->L, -1, "init");
    lua_call(x->L, 0, 0);
	
	// create a new buffer reference, initially referencing a buffer with the provided name
	x->w_buf = buffer_ref_new((t_object *)x, x->w_name);
	x->w_env = buffer_ref_new((t_object *)x, x->w_envname);

	t_buffer_obj* b = buffer_ref_getobject(x->w_buf);
	t_buffer_obj* e = buffer_ref_getobject(x->w_env);
	
	x->w_len = buffer_getframecount(b);
	x->w_envlen = buffer_getframecount(e);


	return (x);
}




void luagran_free(t_luagran *x)
{
	dsp_free((t_pxobject *)x);

	object_free(x->w_buf);
	object_free(x->w_env);
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
// SET BUFFER
////

void luagran_setbuffers(t_luagran* x, t_symbol* s, long ac, t_atom* av) {

	buffer_ref_set(x->w_buf, x->w_name);
	buffer_ref_set(x->w_env, x->w_envname);

	t_buffer_obj* b = buffer_ref_getobject(x->w_buf);
	t_buffer_obj* e = buffer_ref_getobject(x->w_env);

	x->w_len = buffer_getframecount(b);
	x->w_envlen = buffer_getframecount(e);
}

void luagran_set(t_luagran* x, t_symbol* s, long argc, t_atom* argv) {
	x->w_name = atom_getsymarg(0, argc, argv);
	x->w_envname = atom_getsymarg(1, argc, argv);
	defer((t_object*)x, (method)luagran_setbuffers, NULL, 0, NULL);
}

// A notify method is required for our buffer reference
// This handles notifications when the buffer appears, disappears, or is modified.
t_max_err luagran_notify(t_luagran *x, t_symbol *s, t_symbol *msg, void *sender, void *data)
{
	defer((t_object*)x, (method)luagran_setbuffers, NULL, 0, NULL);
	if (s == x->w_name){
		return buffer_ref_notify(x->w_buf, s, msg, sender, data);
	}
	else if (s == x->w_envname)
	{
		return buffer_ref_notify(x->w_env, s, msg, sender, data);
	}
}
		
	


void luagran_assist(t_luagran *x, void *b, long m, long a, char *s)
{
	if (m == ASSIST_INLET) {	// inlets
		switch (a) {
		case 0:	snprintf_zero(s, 256, "Various messages");	break;
		}
	}
	else if (m == ASSIST_OUTLET){	// outlet
		switch (a) {
		case 0:	snprintf_zero(s, 256, "(signal) right output");	break;
		case 1:	snprintf_zero(s, 256, "(signal) left output");	break;
		}
	}
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
void luagran_perform64(t_luagran *x, t_object *dsp64, double **ins, long numins, double **outs, long numouts, long sampleframes, long flags, void *userparam)
{
	t_double		*r_out = outs[0];
	t_double		*l_out = outs[1];
	
	
	int				n = sampleframes;
	float			*b;
	float			*e;
	
	t_buffer_obj	*buffer = buffer_ref_getobject(x->w_buf);
	t_buffer_obj	*env = buffer_ref_getobject(x->w_env);

	b = buffer_locksamples(buffer);
	e = buffer_locksamples(env);
	
	if (!b ||!e|| !x->running)
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
	
	
	

	buffer_unlocksamples(buffer);
	buffer_unlocksamples(env);
	return;
zero:
	while (n--) {
			
		*l_out++ = 0.;
		*r_out++ = 0.;
	}
}

// adjust for the appropriate number of inlets and outlets (2 out, no in)
void luagran_dsp64(t_luagran *x, t_object *dsp64, short *count, double samplerate, long maxvectorsize, long flags)
{
	object_method(dsp64, gensym("dsp_add64"), x, luagran_perform64, 0, NULL);
}
