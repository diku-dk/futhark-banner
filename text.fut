import "lib/github.com/diku-dk/cpprandom/random"
import "lib/github.com/diku-dk/segmented/segmented"
import "drawing"
import "font"

module F = OpenBaskerville

type text_meta = { curves: {start:i64, len:i64},
                   lines:  {start:i64, len:i64}
                 }

type~ state = {time: f32, h: i64, w: i64,
               moving: (i32, i32),
               mouse: (i32, i32),
               paused: bool,
	       resolution:i32,
               text_lines: []line,
               text_curves: []cbezier,
               text_meta: []text_meta
}

module rng_engine = minstd_rand
module rand_i32 = uniform_int_distribution i32 rng_engine
module rand_u32 = uniform_int_distribution u32 rng_engine

entry init (h: i64) (w: i64): state =
  {time = 0, w, h,
   moving = (0,0),
   mouse = (0,0),
   paused = false,
   resolution = 1,
   text_lines = [],
   text_curves = [],
   text_meta = []
}

def modify (s:f32) (t:f32) (p:point0) : point0 =
  (s*(f32.cos (t*10.0) * 20), s*(f32.sin t * 10)) <+> (fpoint0_from_point0 p)
  |> point0_from_fpoint0

def transl ((x,y):point0) (l:line) : line =
  l with p0=(l.p0.0+x,l.p0.1+y)
    with p1=(l.p1.0+x,l.p1.1+y)

def transl' ((x,y):point0) (p:point) =
  p with p = (p.p.0+x,p.p.1+y)

def halfer (r:i32) (grid: [][]color) : [][]color =
  loop g = grid for _i < r-1 do half g

def doubler (r:i32) (grid: [][]color) : [][]color =
  loop g = grid for _i < r-1 do scalei2d 2 g

def scp (s:i32) ((x,y):point0) : point0 = (x/s, y/s)

type^ obj = {lines:[]line, curves:[]cbezier}

def scale_obj (s: i32) (g:obj) : obj =
  {lines=map (\(l:line) -> l with p0=scp s l.p0 with p1=scp s l.p1) g.lines,
   curves=map (\(u:cbezier) -> u with p0=scp s u.p0 with p1=scp s u.p1
  	                                            with p2=scp s u.p2 with p3=scp s u.p3) g.curves}

def transl_point ((x,y):point0) ((a,b):point0) : point0 = (a+x,b+y)

def transl_line (p:point0) (l:line) : line =
  l with p0=transl_point p l.p0 with p1=transl_point p l.p1

def transl_curve (p:point0) (u:cbezier) : cbezier =
  u with p0=transl_point p u.p0 with p1=transl_point p u.p1
                                with p2=transl_point p u.p2 with p3=transl_point p u.p3

def transl_obj (p:point0) (g:obj) : obj =
  {lines=map (transl_line p) g.lines,
   curves=map (transl_curve p) g.curves}

def ymirror_point (y:i32) ((a,b):point0) : point0 = (a,y-b)

def ymirror_line (y:i32) (l:line) : line =
  l with p0=ymirror_point y l.p0 with p1=ymirror_point y l.p1

def ymirror_curve (y:i32) (u:cbezier) : cbezier =
  u with p0=ymirror_point y u.p0 with p1=ymirror_point y u.p1
                                 with p2=ymirror_point y u.p2 with p3=ymirror_point y u.p3

def ymirror_obj (y:i32) (g:obj) : obj =
  {lines=map (ymirror_line y) g.lines,
   curves=map (ymirror_curve y) g.curves}

entry add_text [n] (s: state) (text: [n]u8) (x: i32) (y: i32) (scale: i32) : state =
  let glyfinfos = map (\c -> match F.glyph c
			     case #Some x -> x
			     case #None -> {char=0u8,nlines=0,ncurves=0,advance=0,firstlineidx=0,firstcurveidx=0})
                      text
  let text_advances = ([0] ++ scan (+) 0 (map (\gi -> gi.advance) glyfinfos))[:n]

  let text_lines = expand (\(gi,_) -> i64.i32 gi.nlines)
                          (\(gi,adv) i -> #[unsafe] F.lines[i64.i32 gi.firstlineidx+i] |> transl_line (adv,0))
                          (zip glyfinfos text_advances)

  let text_curves = expand (\(gi,_) -> i64.i32 gi.ncurves)
                           (\(gi,adv) i -> #[unsafe] F.curves[i64.i32 gi.firstcurveidx+i] |> transl_curve (adv,0))
                           (zip glyfinfos text_advances)

  let text_obj = {lines = text_lines, curves = text_curves}
                 |> ymirror_obj 700
                 |> scale_obj scale
                 |> transl_obj (x,y)

  in s with text_lines = s.text_lines ++ text_obj.lines
       with text_curves = s.text_curves ++ text_obj.curves

entry render (s: state) =
  let points = points_of_lbeziers_antialiased s.text_lines
               ++ points_of_cbeziers_antialiased s.text_curves

  in drawpoints s.h s.w points
     |> halfer (s.resolution)
     |> doubler (s.resolution)
