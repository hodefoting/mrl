-- ffi lua binding for microraptor gui by Øyvind Kolås, public domain
--
--
local ffi = require('ffi')
local C = ffi.load('lyd-0.0.so')
local M = setmetatable({C=C},{__index = C})

ffi.cdef[[
typedef struct _Lyd Lyd;
Lyd        *lyd_new             (void);
void        lyd_free            (Lyd *lyd);
void        lyd_set_voice_count (Lyd *lyd, int voice_count);
int         lyd_get_voice_count (Lyd *lyd);

void        lyd_set_sample_rate (Lyd *lyd, int sample_rate);
int         lyd_get_sample_rate (Lyd *lyd);
typedef enum {
  LYD_f32,  /* 32bit floating point mono */
  LYD_f32S, /* 32bit floating point stereo, stream2 is used */
  LYD_s16S  /* 16bit signed integer stereo, interleaved on stream1*/
} LydFormat;

void        lyd_set_format      (Lyd *lyd, LydFormat format);

LydFormat   lyd_get_format      (Lyd *lyd);

long        lyd_synthesize      (Lyd *lyd, int len, void *stream, void *stream2);

typedef struct _LydProgram LydProgram;

LydProgram *lyd_compile         (Lyd *lyd, const char *source);

void        lyd_program_free    (LydProgram *program);

typedef struct _LydVM LydVM;

typedef LydVM LydVoice;

LydVoice   *lyd_voice_new       (Lyd *lyd, LydProgram *program, double delay, int tag);

void        lyd_voice_release   (LydVoice *voice);

void        lyd_kill            (Lyd *lyd, int tag);

void        lyd_voice_kill      (LydVoice *voice);

LydVoice   *lyd_voice_set_delay (LydVoice *voice, double seconds);

LydVoice   *lyd_voice_set_duration (LydVoice *voice, double duration);

LydVoice   *lyd_voice_set_position (LydVoice *voice,
                                    double    position);

LydVoice   *lyd_voice_set_param (LydVoice *voice,
                                 const char *param, double value);

typedef enum {
  LYD_GAP,    /* all values in transition are 0.0 */
  LYD_STEP,   /* all values before value have previous value */
  LYD_LINEAR, /* slide linearly between values */
  LYD_CUBIC   /* slide smoothly between values */
} LydInterpolation;


LydVoice   *lyd_voice_set_param_delayed (LydVoice *voice,
                                         const char *param, double    time,
                                         LydInterpolation interpolation,
                                         double      value);


void lyd_vm_set_param (LydVM      *vm,
                       const char *param,
                       double      value);


void lyd_vm_set_param_delayed (LydVM *vm,
                               const char *param_name, double time,
                               LydInterpolation interpolation,
                               double      value);

void        lyd_load_wave (Lyd *lyd, const char *wavename,
                           int  samples, int sample_rate,
                           float *data);

void        lyd_set_wave_handler (Lyd *lyd,
                                  int (*wave_handler) (Lyd *lyd, const char *wave,
                                                       void *user_data),
                                  void *user_data);

void        lyd_set_var_handler (Lyd *lyd,
                                 void (*var_handler) (Lyd *lyd,
                                                      const char *var,
                                                      double default_value,
                                                      void *user_data),
                                 void *user_data);
void        lyd_set_var_handler_full (Lyd *lyd,
                                 void (*var_handler) (Lyd *lyd,
                                                      const char *var,
                                                      double default_value,
                                                      void *user_data),
                                 void *user_data,
                                 void (*destroy_notify)(void *destroy_data),
                                 void *destroy_data);

typedef LydVM LydFilter;

LydFilter  *lyd_filter_new      (Lyd *lyd, LydProgram *program);


void        lyd_filter_process  (LydFilter *filter,
                                 float    **inputs,
                                 int        n_inputs,
                                 float     *output,
                                 int        samples);


void        lyd_filter_free     (LydFilter *filter);


void        lyd_set_global_filter (Lyd *lyd, LydProgram *program);


const char * lyd_get_patch (Lyd *lyd, int no);

void         lyd_set_patch (Lyd *lyd, int no, const char *patch);

int          lyd_audio_init (Lyd *lyd, const char *driver);

LydVoice *lyd_note (Lyd *lyd, int patch, float hz, float volume, float duration);


LydVoice *lyd_note_full (Lyd *lyd, int patch, float hz, float volume,
                         float duration, float pan, int tag);



int          lyd_add_pre_cb (Lyd *lyd,
                             void (*cb)(Lyd *lyd, float elapsed, void *data),
                             void *data);
int          lyd_add_post_cb (Lyd *lyd,
                              void (*cb)(Lyd *lyd, int samples,
                                         void *stream, void *stream2,
                                         void *data),
                              void *data);

double lyd_get_time (Lyd *lyd);
void lyd_reset_time (Lyd *lyd);

]]

function M.new()
  local lyd = ffi.gc(C.lyd_new(),C.lyd_free)
  lyd:audio_init "auto"
  return lyd
end

ffi.metatype('Lyd', {__index = {
  -- maybe we should add a _full version to this as well, then all callback
  -- things in the code would be lifecycle managed.
  note       = function (...) return C.lyd_note(...) end,
  note_full  = function (...) return C.lyd_note_full(...) end,
  get_time = function (...) return C.lyd_get_time(...) end,
  reset_time = function (...) C.lyd_reset_time(...) end,

  add_pre_cb =
  function (lyd,cb,data)
    local notify_fun, cb_fun;
    local notify_cb = function (finalize_data)
      cb_fun:free();
      --notify_fun:free();
      return 0;
    end

    cb_fun = ffi.cast ("int (*)(Lyd *, double , void *)", cb)
    --notify_fun = ffi.cast ("void (*)(void*)", notify_cb)

    return C.lyd_add_pre_cb(lyd, cb_fun, nil)
  end,
  audio_init = function (...) C.lyd_audio_init(...) end,
  set_sample_rate = function (...) C.lyd_set_sample_rate(...) end,
  get_sample_rate = function (...) return C.lyd_get_sample_rate(...) end,
  set_patch  = function (...) C.lyd_set_patch(...) end,
  kill = function (...) C.lyd_kill(...) end,

  set_var_handler = function (lyd, cb, data)
    -- manually cast and destroy resources held by lua/C binding
    local notify_fun, cb_fun;
    local notify_cb = function (finalize_data)
      cb_fun:free();
      notify_fun:free();
      return 0;
    end

    cb_fun = ffi.cast ("void (*)(Lyd *, const char *, double , void *)", cb)
    notify_fun = ffi.cast ("void (*)(void*)", notify_cb)
    return C.lyd_set_var_handler_full (lyd, cb_fun, data, notify_fun, NULL)
  end,
  get_patch  = function (...) return C.lyd_get_patch(...) end,
  voice_new = function (...) return C.lyd_voice_new(...) end,
  compile = function (...) return ffi.gc(C.lyd_compile(...), C.lyd_program_free) end
}})

ffi.metatype('LydVoice', {__index = { 
  release = function (...) return C.lyd_voice_release(...) end,
  kill    = function (...) C.lyd_voice_kill(...) end,
  set_delay = function (...) return C.lyd_voice_set_delay(...) end,
  set_duration = function (...) return C.lyd_voice_set_duration(...) end,
  set_position = function (...) return C.lyd_voice_set_position(...) end,
  set_param = function (...) return C.lyd_voice_set_param(...) end

}})
ffi.metatype('LydProgram', {__index = { 
  free = function (...) C.lyd_program_free(...) end
}})

M.GAP    = C.LYD_GAP
M.STEP   = C.LYD_STEP
M.LINEAR = C.LYD_LINEAR
M.CUBIC  = C.LYD_CUBIC

return M
