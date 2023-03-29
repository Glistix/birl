import gleam/int
import gleam/bool
import gleam/list
import gleam/order
import gleam/regex
import gleam/result
import gleam/string
import gleam/option
import gleam/function
import gleam/iterator
import birl/duration
import ranger

pub opaque type Time {
  Time(wall_time: Int, offset: Int, monotonic_time: option.Option(Int))
}

pub type Weekday {
  Monday
  Tuesday
  Wednesday
  Thursday
  Friday
  Saturday
  Sunday
}

pub type Month {
  January
  February
  March
  April
  May
  June
  July
  August
  September
  October
  November
  December
}

/// use this to get the current time in the local timezone offset
pub fn now() -> Time {
  let now = ffi_now()
  let offset_in_minutes = ffi_local_offset()
  let monotonic_now = ffi_monotonic_now()
  Time(now, offset_in_minutes * 60_000_000, option.Some(monotonic_now))
}

/// use this to get the current time in utc
pub fn utc_now() -> Time {
  let now = ffi_now()
  let monotonic_now = ffi_monotonic_now()
  Time(now, 0, option.Some(monotonic_now))
}

/// use this to get the current time with a given offset.
///
/// Some examples of acceptable offsets:
///
/// `"+330", "03:30", "-8:00","-7", "-0400", "03"`
pub fn now_with_offset(offset: String) -> Result(Time, Nil) {
  use offset <- result.then(parse_offset(offset))
  let now = ffi_now()
  let monotonic_now = ffi_monotonic_now()
  Time(now, offset, option.Some(monotonic_now))
  |> Ok
}

/// use this tp change the offset of a given time value.
///
/// Some examples of acceptable offsets:
///
/// `"+330", "03:30", "-8:00","-7", "-0400", "03"`
pub fn change_offset(value: Time, new_offset: String) -> Result(Time, Nil) {
  use new_offset_number <- result.then(parse_offset(new_offset))
  case value {
    Time(wall_time: t, offset: _, monotonic_time: mt) ->
      Time(t, new_offset_number, mt)
      |> Ok
  }
}

pub fn to_parts(
  value: Time,
) -> #(#(Int, Int, Int), #(Int, Int, Int, Int), String) {
  case value {
    Time(wall_time: t, offset: o, monotonic_time: _) -> {
      let #(date, time) = ffi_to_parts(t, o)
      let assert Ok(offset) = generate_offset(o)
      #(date, time, offset)
    }
  }
}

pub fn from_parts(
  date: #(Int, Int, Int),
  time: #(Int, Int, Int, Int),
  offset: String,
) -> Result(Time, Nil) {
  use offset_number <- result.then(parse_offset(offset))
  ffi_from_parts(#(date, time), offset_number)
  |> Time(offset_number, option.None)
  |> Ok
}

pub fn to_iso8601(value: Time) -> String {
  let #(#(year, month, day), #(hour, minute, second, milli_second), offset) =
    to_parts(value)

  int.to_string(year) <> "-" <> {
    month
    |> int.to_string
    |> string.pad_left(2, "0")
  } <> "-" <> {
    day
    |> int.to_string
    |> string.pad_left(2, "0")
  } <> "T" <> {
    hour
    |> int.to_string
    |> string.pad_left(2, "0")
  } <> ":" <> {
    minute
    |> int.to_string
    |> string.pad_left(2, "0")
  } <> ":" <> {
    second
    |> int.to_string
    |> string.pad_left(2, "0")
  } <> "." <> {
    milli_second
    |> int.to_string
    |> string.pad_left(3, "0")
  } <> offset
}

pub fn from_iso8601(value: String) -> Result(Time, Nil) {
  let assert Ok(offset_pattern) = regex.from_string("(.*)([+|\\-].*)")
  let value = string.trim(value)

  let #(date_string, offsetted_time_string) = case string.split(value, "T") {
    [date_string] -> #(date_string, "00")
    [date_string, offsetted_time_string] -> #(
      date_string,
      offsetted_time_string,
    )
  }

  let #(time_string, offset_string) = case
    string.ends_with(offsetted_time_string, "Z")
  {
    True -> #(string.drop_right(offsetted_time_string, 1), "+00:00")
    False ->
      case regex.scan(offset_pattern, offsetted_time_string) {
        [regex.Match(_, [option.Some(time_string), option.Some(offset_string)])] -> #(
          time_string,
          offset_string,
        )
        [] -> {
          let local_offset_in_minutes = ffi_local_offset()
          let assert Ok(local_offset_string) =
            generate_offset(local_offset_in_minutes * 60_000_000)

          #(offsetted_time_string, local_offset_string)
        }
      }
  }

  let time_string = string.replace(time_string, ":", "")
  let #(time_string, milli_seconds_result) = case
    string.split(time_string, ".")
  {
    [time_string] -> #(time_string, Ok(0))
    [time_string, milli_seconds_string] -> #(
      time_string,
      int.parse(milli_seconds_string),
    )
  }

  case milli_seconds_result {
    Ok(milli_seconds) -> {
      use [year, month, day] <- result.then(parse_date(date_string))
      use [hour, minute, second] <- result.then(parse_time(time_string))

      case
        from_parts(
          #(year, month, day),
          #(hour, minute, second, milli_seconds),
          offset_string,
        )
      {
        Ok(Time(timestamp, offset, option.None)) ->
          Ok(Time(timestamp, offset, option.None))

        Error(Nil) -> Error(Nil)
      }
    }

    Error(Nil) -> Error(Nil)
  }
}

/// see [here](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Date)
pub fn to_http(value: Time) -> String {
  let assert Ok(utc_value) = change_offset(value, "Z")

  let #(#(year, _, day), #(hour, minute, second, _), _) = to_parts(utc_value)
  let short_weekday = short_string_weekday(utc_value)
  let short_month = short_string_month(utc_value)

  short_weekday <> ", " <> {
    day
    |> int.to_string
    |> string.pad_left(2, "0")
  } <> " " <> short_month <> " " <> int.to_string(year) <> " " <> {
    hour
    |> int.to_string
    |> string.pad_left(2, "0")
  } <> ":" <> {
    minute
    |> int.to_string
    |> string.pad_left(2, "0")
  } <> ":" <> {
    second
    |> int.to_string
    |> string.pad_left(2, "0")
  } <> " GMT"
}

/// see [here](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Date)
pub fn from_http(value: String) -> Result(Time, Nil) {
  let value = string.trim(value)
  let [weekday, rest] = string.split(value, ",")
  use <- bool.guard(
    !list.contains(
      list.map(
        weekday_strings,
        fn(weekday) {
          let strings = weekday.1
          strings.1
        },
      ),
      weekday,
    ),
    Error(Nil),
  )

  let rest = string.trim(rest)
  let assert Ok(whitespace_pattern) = regex.from_string("\\s+")
  case regex.split(whitespace_pattern, rest) {
    [day_string, short_month, year_string, time_string, "GMT"] -> {
      let time_string = string.replace(time_string, ":", "")
      case
        #(
          int.parse(day_string),
          month_strings
          |> list.index_map(fn(index, month) {
            let strings = month.1
            #(index, strings.1)
          })
          |> list.find(fn(month) { month.1 == short_month }),
          int.parse(year_string),
          parse_time(time_string),
        )
      {
        #(Ok(day), Ok(#(month_index, _)), Ok(year), Ok([hour, minute, second])) ->
          case
            from_parts(
              #(year, month_index + 1, day),
              #(hour, minute, second, 0),
              "Z",
            )
          {
            Ok(value) -> {
              let correct_weekday = short_string_weekday(value)
              case correct_weekday == weekday {
                True -> Ok(value)
                False -> Error(Nil)
              }
            }
            Error(Nil) -> Error(Nil)
          }
        _ -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

/// unix timestamps are the number of seconds that have elapsed since 00:00:00 UTC on January 1st, 1970
pub fn to_unix(value: Time) -> Int {
  case value {
    Time(t, _, _) -> t / 1_000_000
  }
}

/// unix timestamps are the number of seconds that have elapsed since 00:00:00 UTC on January 1st, 1970
pub fn from_unix(value: Int) -> Time {
  Time(value * 1_000_000, 0, option.None)
}

pub fn compare(a: Time, b: Time) -> order.Order {
  let Time(wall_time: wta, offset: _, monotonic_time: mta) = a
  let Time(wall_time: wtb, offset: _, monotonic_time: mtb) = b

  let #(ta, tb) = case #(mta, mtb) {
    #(option.Some(ta), option.Some(tb)) -> #(ta, tb)
    _ -> #(wta, wtb)
  }

  case ta == tb {
    True -> order.Eq
    False ->
      case ta < tb {
        True -> order.Lt
        False -> order.Gt
      }
  }
}

pub fn difference(a: Time, b: Time) -> duration.Duration {
  let Time(wall_time: wta, offset: _, monotonic_time: mta) = a
  let Time(wall_time: wtb, offset: _, monotonic_time: mtb) = b

  let #(ta, tb) = case #(mta, mtb) {
    #(option.Some(ta), option.Some(tb)) -> #(ta, tb)
    _ -> #(wta, wtb)
  }

  duration.Duration(ta - tb)
}

pub fn add(value: Time, duration: duration.Duration) -> Time {
  let Time(wall_time: wt, offset: o, monotonic_time: mt) = value
  let duration.Duration(duration) = duration
  case mt {
    option.Some(mt) ->
      Time(
        wall_time: wt + duration,
        offset: o,
        monotonic_time: option.Some(mt + duration),
      )
    option.None ->
      Time(wall_time: wt + duration, offset: o, monotonic_time: option.None)
  }
}

pub fn subtract(value: Time, duration: duration.Duration) -> Time {
  let Time(wall_time: wt, offset: o, monotonic_time: mt) = value
  let duration.Duration(duration) = duration
  case mt {
    option.Some(mt) ->
      Time(
        wall_time: wt - duration,
        offset: o,
        monotonic_time: option.Some(mt - duration),
      )
    option.None ->
      Time(wall_time: wt - duration, offset: o, monotonic_time: option.None)
  }
}

pub fn weekday(value: Time) -> Weekday {
  case value {
    Time(wall_time: t, offset: o, monotonic_time: _) -> {
      let assert Ok(weekday) = list.at(weekdays, ffi_weekday(t, o))
      weekday
    }
  }
}

pub fn string_weekday(value: Time) -> String {
  let weekday = weekday(value)
  let assert Ok(#(weekday, _)) = list.key_find(weekday_strings, weekday)
  weekday
}

pub fn short_string_weekday(value: Time) -> String {
  let weekday = weekday(value)
  let assert Ok(#(_, weekday)) = list.key_find(weekday_strings, weekday)
  weekday
}

pub fn month(value: Time) -> Month {
  let #(#(_, month, _), _, _) = to_parts(value)
  let assert Ok(month) = list.at(months, month - 1)
  month
}

pub fn string_month(value: Time) -> String {
  let month = month(value)
  let assert Ok(#(month, _)) = list.key_find(month_strings, month)
  month
}

pub fn short_string_month(value: Time) -> String {
  let month = month(value)
  let assert Ok(#(_, month)) = list.key_find(month_strings, month)
  month
}

pub fn range(a: Time, b: Time, s: duration.Duration) -> iterator.Iterator(Time) {
  let assert Ok(range) =
    ranger.create(
      validate: fn(_) { True },
      negate_step: fn(duration) {
        let duration.Duration(value) = duration
        duration.Duration(-1 * value)
      },
      add: add,
      compare: compare,
    )(
      a,
      b,
      s,
    )
  range
  |> ranger.unwrap
}

fn parse_offset(offset: String) -> Result(Int, Nil) {
  use <- bool.guard(list.contains(["Z", "z"], offset), Ok(0))
  let assert Ok(re) = regex.from_string("([+-])")

  use #(sign, offset) <- result.then(case regex.split(re, offset) {
    ["", "+", offset] -> Ok(#(1, offset))
    ["", "-", offset] -> Ok(#(-1, offset))
    [_] -> Ok(#(1, offset))
    _ -> Error(Nil)
  })

  case string.split(offset, ":") {
    [hour_str, minute_str] -> {
      use hour <- result.then(int.parse(hour_str))
      use minute <- result.then(int.parse(minute_str))
      Ok(sign * { hour * 60 + minute } * 60 * 1_000_000)
    }
    [offset] ->
      case string.length(offset) {
        1 | 2 -> {
          use hour <- result.then(int.parse(offset))
          Ok(sign * hour * 3600 * 1_000_000)
        }
        3 -> {
          let assert Ok(hour_str) = string.first(offset)
          let minute_str = string.slice(offset, 1, 2)
          use hour <- result.then(int.parse(hour_str))
          use minute <- result.then(int.parse(minute_str))
          Ok(sign * { hour * 60 + minute } * 60 * 1_000_000)
        }
        4 -> {
          let hour_str = string.slice(offset, 0, 2)
          let minute_str = string.slice(offset, 2, 2)
          use hour <- result.then(int.parse(hour_str))
          use minute <- result.then(int.parse(minute_str))
          Ok(sign * { hour * 60 + minute } * 60 * 1_000_000)
        }
        _ -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

fn generate_offset(offset: Int) -> Result(String, Nil) {
  use <- bool.guard(offset == 0, Ok("Z"))
  case
    [#(offset, duration.MicroSecond)]
    |> duration.new
    |> duration.decompose
  {
    [#(hour, duration.Hour), #(minute, duration.Minute)] ->
      [
        case hour > 0 {
          True ->
            string.concat([
              "+",
              hour
              |> int.to_string
              |> string.pad_left(2, "0"),
            ])
          False ->
            string.concat([
              "-",
              hour
              |> int.absolute_value
              |> int.to_string
              |> string.pad_left(2, "0"),
            ])
        },
        minute
        |> int.absolute_value
        |> int.to_string
        |> string.pad_left(2, "0"),
      ]
      |> string.join(":")
      |> Ok

    [#(hour, duration.Hour)] ->
      [
        case hour > 0 {
          True ->
            string.concat([
              "+",
              hour
              |> int.to_string
              |> string.pad_left(2, "0"),
            ])
          False ->
            string.concat([
              "-",
              hour
              |> int.absolute_value
              |> int.to_string
              |> string.pad_left(2, "0"),
            ])
        },
        "00",
      ]
      |> string.join(":")
      |> Ok
    _ -> Error(Nil)
  }
}

fn parse_date(date: String) -> Result(List(Int), Nil) {
  let assert Ok(dash_pattern) =
    regex.from_string(
      "(\\d{4})(?:-(1[0-2]|0?[0-9]))?(?:-(3[0-1]|[1-2][0-9]|0?[0-9]))?",
    )

  case regex.scan(dash_pattern, date) {
    [regex.Match(_, [option.Some(major)])] -> [int.parse(major), Ok(1), Ok(1)]

    [regex.Match(_, [option.Some(major), option.Some(middle)])] -> [
      int.parse(major),
      int.parse(middle),
      Ok(1),
    ]

    [
      regex.Match(
        _,
        [option.Some(major), option.Some(middle), option.Some(minor)],
      ),
    ] -> [int.parse(major), int.parse(middle), int.parse(minor)]

    _ ->
      parse_iso_section(
        date,
        "(\\d{4})(1[0-2]|0?[0-9])?(3[0-1]|[1-2][0-9]|0?[0-9])?",
        1,
      )
  }
  |> list.try_map(function.identity)
}

fn parse_time(time: String) -> Result(List(Int), Nil) {
  parse_iso_section(
    time,
    "(2[0-3]|1[0-9]|0?[0-9])([1-5][0-9]|0?[0-9])?([1-5][0-9]|0?[0-9])?",
    0,
  )
  |> list.try_map(function.identity)
}

fn parse_iso_section(
  section: String,
  pattern_string: String,
  default: Int,
) -> List(Result(Int, Nil)) {
  let assert Ok(pattern) = regex.from_string(pattern_string)
  case regex.scan(pattern, section) {
    [regex.Match(_, [option.Some(major)])] -> [
      int.parse(major),
      Ok(default),
      Ok(default),
    ]

    [regex.Match(_, [option.Some(major), option.Some(middle)])] -> [
      int.parse(major),
      int.parse(middle),
      Ok(default),
    ]

    [
      regex.Match(
        _,
        [option.Some(major), option.Some(middle), option.Some(minor)],
      ),
    ] -> [int.parse(major), int.parse(middle), int.parse(minor)]

    _ -> [Error(Nil)]
  }
}

if erlang {
  const weekdays = [
    Monday,
    Tuesday,
    Wednesday,
    Thursday,
    Friday,
    Saturday,
    Sunday,
  ]
}

if javascript {
  const weekdays = [
    Sunday,
    Monday,
    Tuesday,
    Wednesday,
    Thursday,
    Friday,
    Saturday,
  ]
}

const months = [
  January,
  February,
  March,
  April,
  May,
  June,
  July,
  August,
  September,
  October,
  November,
  December,
]

const weekday_strings = [
  #(Monday, #("Monday", "Mon")),
  #(Tuesday, #("Tuesday", "Tue")),
  #(Wednesday, #("Wednesday", "Wed")),
  #(Thursday, #("Thursday", "Thu")),
  #(Friday, #("Friday", "Fri")),
  #(Saturday, #("Saturday", "Sat")),
  #(Sunday, #("Sunday", "Sun")),
]

const month_strings = [
  #(January, #("January", "Jan")),
  #(February, #("February", "Feb")),
  #(March, #("March", "Mar")),
  #(April, #("April", "Apr")),
  #(May, #("May", "May")),
  #(June, #("June", "Jun")),
  #(July, #("July", "Jul")),
  #(August, #("August", "Aug")),
  #(September, #("September", "Sep")),
  #(October, #("October", "Oct")),
  #(November, #("November", "Nov")),
  #(December, #("December", "Dec")),
]

if erlang {
  external fn ffi_now() -> Int =
    "birl_ffi" "now"

  external fn ffi_local_offset() -> Int =
    "birl_ffi" "local_offset"

  external fn ffi_monotonic_now() -> Int =
    "birl_ffi" "monotonic_now"

  external fn ffi_to_parts(
    Int,
    Int,
  ) -> #(#(Int, Int, Int), #(Int, Int, Int, Int)) =
    "birl_ffi" "to_parts"

  external fn ffi_from_parts(
    #(#(Int, Int, Int), #(Int, Int, Int, Int)),
    Int,
  ) -> Int =
    "birl_ffi" "from_parts"

  external fn ffi_weekday(Int, Int) -> Int =
    "birl_ffi" "weekday"
}

if javascript {
  external fn ffi_now() -> Int =
    "../birl_ffi.mjs" "now"

  external fn ffi_local_offset() -> Int =
    "../birl_ffi.mjs" "local_offset"

  external fn ffi_monotonic_now() -> Int =
    "../birl_ffi.mjs" "monotonic_now"

  external fn ffi_to_parts(
    Int,
    Int,
  ) -> #(#(Int, Int, Int), #(Int, Int, Int, Int)) =
    "../birl_ffi.mjs" "to_parts"

  external fn ffi_from_parts(
    #(#(Int, Int, Int), #(Int, Int, Int, Int)),
    Int,
  ) -> Int =
    "../birl_ffi.mjs" "from_parts"

  external fn ffi_weekday(Int, Int) -> Int =
    "../birl_ffi.mjs" "weekday"
}
