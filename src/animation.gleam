//// Note, you can use this library to animate *any* type. However, some operations require you to provide a *merge* function `fn(a) -> a`. (Or more formally, what's sometimes called a monoid.)
//// For example, to animate [paint](https://hexdocs.pm/paint/) `Picture`s, you would provide the `paint.combine` function:
//// ```
//// type AnimatedPicture = animation.Animation(paint.Picture)
//// pub fn parallel(a: AnimatedPicture, AnimatedPicture) -> AnimatedPicture {
////   animation.parallel(a, b, using: paint.combine)
//// }
//// ```

import gleam/float
import gleam/option.{type Option}

pub type Time =
  Float

pub type Duration =
  Float

// ------------ Play animations ----------

pub opaque type PlayingAnimation(a) {
  PlayingAnimation(animation: Animation(a), elapsed_time: Duration)
}

pub fn start_playing(animation: Animation(a)) -> PlayingAnimation(a) {
  // Note: we know that an animation must be longer than 0 time units, so we
  // can safely construct a playing animation
  PlayingAnimation(animation, elapsed_time: 0.0)
}

pub fn play(
  playing: PlayingAnimation(a),
  dt dt: Time,
) -> Option(PlayingAnimation(a)) {
  let time = playing.elapsed_time +. dt
  let duration = playing.animation.duration

  case time >. duration {
    True -> {
      // The animation has anded
      option.None
    }
    False -> {
      option.Some(PlayingAnimation(..playing, elapsed_time: time))
    }
  }
}

pub fn view_now(playing: PlayingAnimation(a)) -> a {
  let time = playing.elapsed_time
  let normalized_time =
    case time {
      0.0 -> 0.0
      _ -> time /. playing.animation.duration
    }
    |> float.clamp(0.0, 1.0)

  playing.animation.view(normalized_time)
}

pub fn view_at(animation: Animation(a), time time: Time) -> a {
  let time = float.clamp(0.0, time, 1.0)
  animation.view(time)
}

// ------------ Create animations ----------

pub opaque type Animation(a) {
  Animation(duration: Time, view: fn(Float) -> a)
}

pub fn new(
  view: fn(Time) -> a,
  duration duration: Duration,
) -> Result(Animation(a), Nil) {
  case duration >. 0.0 {
    False -> Error(Nil)
    True -> Ok(Animation(duration:, view:))
  }
}

pub fn map(animation: Animation(a), with fun: fn(a) -> b) -> Animation(b) {
  let assert Ok(mapped_animation) =
    new(
      fn(t) {
        let a = animation.view(t)
        fun(a)
      },
      duration: animation.duration,
    )
  mapped_animation
}

pub fn then(first: Animation(a), second: Animation(a)) -> Animation(a) {
  let full_duration = first.duration +. second.duration
  Animation(
    fn(time) {
      case time <. first.duration /. full_duration {
        True -> first.view(time *. full_duration /. first.duration)
        False ->
          second.view(
            { time -. first.duration /. full_duration }
            *. full_duration
            /. second.duration,
          )
      }
    },
    duration: full_duration,
  )
}

pub fn parallel(
  a: Animation(a),
  b: Animation(a),
  using merge_op: fn(List(a)) -> a,
) -> Animation(a) {
  let total_duration = float.max(a.duration, b.duration)
  Animation(
    fn(time) {
      let first_time = float.min(1.0, time *. total_duration /. a.duration)
      let second_time = float.min(1.0, time *. total_duration /. b.duration)

      merge_op([a.view(first_time), b.view(second_time)])
    },
    duration: total_duration,
  )
}

pub fn empty(
  duration duration: Duration,
  using merge_op: fn(List(a)) -> a,
) -> Result(Animation(a), Nil) {
  new(
    fn(_) {
      let empty_element = merge_op([])
      empty_element
    },
    duration:,
  )
}

pub fn constant(
  picture: a,
  duration duration: Duration,
) -> Result(Animation(a), Nil) {
  new(fn(_) { picture }, duration:)
}

pub fn continue(
  first: Animation(a),
  second: Animation(a),
  using merge_op: fn(List(a)) -> a,
) -> Animation(a) {
  let assert Ok(wait_until_first_complete) =
    empty(duration: first.duration, using: merge_op)

  parallel(first, wait_until_first_complete |> then(second), using: merge_op)
}

pub fn ease(animation: Animation(a), fun: fn(Time) -> Time) -> Animation(a) {
  Animation(duration: animation.duration, view: fn(t) { animation.view(fun(t)) })
}
