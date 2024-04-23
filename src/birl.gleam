import birl/duration
import birl/zones
import gleam/bool
import gleam/function
import gleam/int
import gleam/iterator
import gleam/list
import gleam/option
import gleam/order
import gleam/regex
import gleam/result
import gleam/string
import ranger

@target(erlang)
const space_regex = "\\s"
@target(erlang)
const digit_regex = "\\d"

@target(javascript)
const space_regex = "\\s"
@target(javascript)
const digit_regex = "\\d"

@target(nix)
const space_regex = "[[:space:]]"
@target(nix)
const digit_regex = "[0-9]"

pub opaque type Time {
  Time(
    wall_time: Int,
    offset: Int,
    timezone: option.Option(String),
    monotonic_time: option.Option(Int),
  )
}

pub type Day {
  Day(year: Int, month: Int, date: Int)
}

pub type TimeOfDay {
  TimeOfDay(hour: Int, minute: Int, second: Int, milli_second: Int)
}

/// starting point of unix timestamps
pub const unix_epoch = Time(0, 0, option.None, option.None)

pub type Weekday {
  Mon
  Tue
  Wed
  Thu
  Fri
  Sat
  Sun
}

pub type Month {
  Jan
  Feb
  Mar
  Apr
  May
  Jun
  Jul
  Aug
  Sep
  Oct
  Nov
  Dec
}

/// use this to get the current time in the local timezone offset
pub fn now() -> Time {
  let now = ffi_now()
  let offset_in_minutes = ffi_local_offset()
  let monotonic_now = ffi_monotonic_now()
  let timezone = local_timezone()

  Time(
    now,
    offset_in_minutes * 60_000_000,
    option.map(timezone, fn(tz) {
      case list.any(zones.list, fn(item) { item.0 == tz }) {
        True -> option.Some(tz)
        False -> option.None
      }
    })
      |> option.flatten,
    option.Some(monotonic_now),
  )
}

/// use this to get the current time in utc
pub fn utc_now() -> Time {
  let now = ffi_now()
  let monotonic_now = ffi_monotonic_now()
  Time(now, 0, option.Some("Etc/UTC"), option.Some(monotonic_now))
}

/// use this to get the current time with a given offset.
///
/// some examples of acceptable offsets:
///
/// `"+330", "03:30", "-8:00","-7", "-0400", "03"`
pub fn now_with_offset(offset: String) -> Result(Time, Nil) {
  use offset <- result.then(parse_offset(offset))
  let now = ffi_now()
  let monotonic_now = ffi_monotonic_now()
  Time(now, offset, option.None, option.Some(monotonic_now))
  |> Ok
}

pub fn now_with_timezone(timezone: String) -> Result(Time, Nil) {
  case list.key_find(zones.list, timezone) {
    Ok(offset) -> {
      let now = ffi_now()
      let monotonic_now = ffi_monotonic_now()
      Time(
        now,
        offset * 1_000_000,
        option.Some(timezone),
        option.Some(monotonic_now),
      )
      |> Ok
    }

    Error(Nil) -> Error(Nil)
  }
}

pub fn monotonic_now() -> Int {
  ffi_monotonic_now()
}

/// returns a string which is the date part of an ISO8601 string along with the offset
pub fn to_date_string(value: Time) -> String {
  let #(#(year, month, day), _, offset) = to_parts(value)

  int.to_string(year)
  <> "-"
  <> {
    month
    |> int.to_string
    |> string.pad_left(2, "0")
  }
  <> "-"
  <> {
    day
    |> int.to_string
    |> string.pad_left(2, "0")
  }
  <> offset
}

/// like `to_date_string` except it does not contain the offset
pub fn to_naive_date_string(value: Time) -> String {
  let #(#(year, month, day), _, _) = to_parts(value)

  int.to_string(year)
  <> "-"
  <> {
    month
    |> int.to_string
    |> string.pad_left(2, "0")
  }
  <> "-"
  <> {
    day
    |> int.to_string
    |> string.pad_left(2, "0")
  }
}

/// returns a string which is the time part of an ISO8601 string along with the offset
pub fn to_time_string(value: Time) -> String {
  let #(_, #(hour, minute, second, milli_second), offset) = to_parts(value)

  {
    hour
    |> int.to_string
    |> string.pad_left(2, "0")
  }
  <> ":"
  <> {
    minute
    |> int.to_string
    |> string.pad_left(2, "0")
  }
  <> ":"
  <> {
    second
    |> int.to_string
    |> string.pad_left(2, "0")
  }
  <> "."
  <> {
    milli_second
    |> int.to_string
    |> string.pad_left(3, "0")
  }
  <> offset
}

/// like `to_time_string` except it does not contain the offset
pub fn to_naive_time_string(value: Time) -> String {
  let #(_, #(hour, minute, second, milli_second), _) = to_parts(value)

  {
    hour
    |> int.to_string
    |> string.pad_left(2, "0")
  }
  <> ":"
  <> {
    minute
    |> int.to_string
    |> string.pad_left(2, "0")
  }
  <> ":"
  <> {
    second
    |> int.to_string
    |> string.pad_left(2, "0")
  }
  <> "."
  <> {
    milli_second
    |> int.to_string
    |> string.pad_left(3, "0")
  }
}

pub fn to_iso8601(value: Time) -> String {
  let #(#(year, month, day), #(hour, minute, second, milli_second), offset) =
    to_parts(value)

  int.to_string(year)
  <> "-"
  <> {
    month
    |> int.to_string
    |> string.pad_left(2, "0")
  }
  <> "-"
  <> {
    day
    |> int.to_string
    |> string.pad_left(2, "0")
  }
  <> "T"
  <> {
    hour
    |> int.to_string
    |> string.pad_left(2, "0")
  }
  <> ":"
  <> {
    minute
    |> int.to_string
    |> string.pad_left(2, "0")
  }
  <> ":"
  <> {
    second
    |> int.to_string
    |> string.pad_left(2, "0")
  }
  <> "."
  <> {
    milli_second
    |> int.to_string
    |> string.pad_left(3, "0")
  }
  <> offset
}

/// if you need to parse an `ISO8601` string, this is probably what you're looking for.
///
/// given the huge surface area that `ISO8601` covers, it does not make sense for `birl`
/// to support all of it in one function, so this function parses only strings for which both
/// day and time of day can be extracted or deduced. Some acceptable examples are given below:
///
///   - `2019t14-4` -> `2019-01-01T14:00:00.000-04:00`
///
///   - `2019-03-26t14:00.9z` -> `2019-03-26T14:00:00.900Z`
///
///   - `2019-03-26+330` -> `2019-03-26T00:00:00.000+03:30`
///
///   - `20190326t1400-4` -> `2019-03-26T14:00:00.000-04:00`
///
///   - `19051222T16:38-3` -> `1905-12-22T16:38:00.000-03:00`
///
///   - `2019-03-26 14:30:00.9Z` -> `2019-03-26T14:30:00.900Z`
///
///   - `2019-03-26T14:00:00.9Z` -> `2019-03-26T14:00:00.900Z`
///
///   - `1905-12-22 16:38:23-3` -> `1905-12-22T16:38:23.000-03:00`
///
///   - `2019-03-26T14:00:00,4999Z` -> `2019-03-26T14:00:00.499Z`
///
///   - `1905-12-22T163823+0330` -> `1905-12-22T16:38:23.000+03:30`
///
///   - `1905-12-22T16:38:23.000+03:30` -> `1905-12-22T16:38:23.000+03:30`
pub fn parse(value: String) -> Result(Time, Nil) {
  let assert Ok(offset_pattern) = regex.from_string("(.*)([+|\\-].*)")
  let value = string.trim(value)

  use #(day_string, offsetted_time_string) <- result.then(case
    string.split(value, "T"),
    string.split(value, "t"),
    string.split(value, " ")
  {
    [day_string, time_string], _, _
    | _, [day_string, time_string], _
    | _, _, [day_string, time_string]
    -> Ok(#(day_string, time_string))
    [_], [_], [_] -> Ok(#(value, "00"))
    _, _, _ -> Error(Nil)
  })

  let day_string = string.trim(day_string)
  let offsetted_time_string = string.trim(offsetted_time_string)

  use #(day_string, time_string, offset_string) <- result.then(case
    string.ends_with(offsetted_time_string, "Z")
    || string.ends_with(offsetted_time_string, "z")
  {
    True ->
      Ok(#(day_string, string.drop_right(offsetted_time_string, 1), "+00:00"))
    False ->
      case regex.scan(offset_pattern, offsetted_time_string) {
        [regex.Match(_, [option.Some(time_string), option.Some(offset_string)])] ->
          Ok(#(day_string, time_string, offset_string))
        _ ->
          case regex.scan(offset_pattern, day_string) {
            [
              regex.Match(
                _,
                [option.Some(day_string), option.Some(offset_string)],
              ),
            ] -> Ok(#(day_string, "00", offset_string))
            _ -> Error(Nil)
          }
      }
  })

  let time_string = string.replace(time_string, ":", "")
  use #(time_string, milli_seconds_result) <- result.then(case
    string.split(time_string, "."),
    string.split(time_string, ",")
  {
    [_], [_] -> {
      Ok(#(time_string, Ok(0)))
    }
    [time_string, milli_seconds_string], [_]
    | [_], [time_string, milli_seconds_string] -> {
      Ok(#(
        time_string,
        milli_seconds_string
          |> string.slice(0, 3)
          |> string.pad_right(3, "0")
          |> int.parse,
      ))
    }

    _, _ -> Error(Nil)
  })

  case milli_seconds_result {
    Ok(milli_seconds) -> {
      use day <- result.then(parse_date_section(day_string))
      let assert [year, month, date] = day

      use time_of_day <- result.then(parse_time_section(time_string))
      let assert [hour, minute, second] = time_of_day

      from_parts(
        #(year, month, date),
        #(hour, minute, second, milli_seconds),
        offset_string,
      )
    }

    Error(Nil) -> Error(Nil)
  }
}

/// this function parses `ISO8601` strings in which no date is specified, which
/// means such inputs don't actually represent a particular moment in time. That's why
/// the result of this function is an instance of `TimeOfDay` along with the offset specificed
/// in the string. Some acceptable examples are given below:
///
///   - `t25z` -> `#(TimeOfDay(2, 5, 0, 0), "Z")`
///
///   - `14-4` -> `#(TimeOfDay(14, 0, 0, 0), "-04:00")`
///
///   - `T145+4` -> `#(TimeOfDay(14, 5, 0, 0), "+04:00")`
///
///   - `16:38-3` -> `#(TimeOfDay(16, 38, 0, 0), "-03:00")`
///
///   - `t14:65.9z` -> `#(TimeOfDay(14, 6, 5, 900), "-04:00")`
///
///   - `163823+0330` -> `#(TimeOfDay(16, 38, 23, 0), "+03:30")`
///
///   - `T16:38:23.050+03:30` -> `#(TimeOfDay(16, 38, 23, 50), "+03:30")`
pub fn parse_time_of_day(value: String) -> Result(#(TimeOfDay, String), Nil) {
  let assert Ok(offset_pattern) = regex.from_string("(.*)([+|\\-].*)")

  let time_string = case
    string.starts_with(value, "T"),
    string.starts_with(value, "t")
  {
    True, _ | _, True -> string.drop_left(value, 1)
    _, _ -> value
  }

  use #(time_string, offset_string) <- result.then(case
    string.ends_with(time_string, "Z")
    || string.ends_with(time_string, "z")
  {
    True -> Ok(#(string.drop_right(value, 1), "+00:00"))
    False ->
      case regex.scan(offset_pattern, value) {
        [regex.Match(_, [option.Some(time_string), option.Some(offset_string)])] ->
          Ok(#(time_string, offset_string))
        _ -> Error(Nil)
      }
  })

  let time_string = string.replace(time_string, ":", "")

  use #(time_string, milli_seconds_result) <- result.then(case
    string.split(time_string, "."),
    string.split(time_string, ",")
  {
    [_], [_] -> {
      Ok(#(time_string, Ok(0)))
    }
    [time_string, milli_seconds_string], [_]
    | [_], [time_string, milli_seconds_string] -> {
      Ok(#(
        time_string,
        milli_seconds_string
          |> string.slice(0, 3)
          |> string.pad_right(3, "0")
          |> int.parse,
      ))
    }
    _, _ -> Error(Nil)
  })

  case milli_seconds_result {
    Ok(milli_seconds) -> {
      use time_of_day <- result.then(parse_time_section(time_string))
      let assert [hour, minute, second] = time_of_day

      use offset <- result.then(parse_offset(offset_string))
      use offset_string <- result.then(generate_offset(offset))

      Ok(#(TimeOfDay(hour, minute, second, milli_seconds), offset_string))
    }
    Error(Nil) -> Error(Nil)
  }
}

/// accepts fromats similar to the ones listed for `parse_time_of_day` except that there shoundn't be any offset information
pub fn parse_naive_time_of_day(
  value: String,
) -> Result(#(TimeOfDay, String), Nil) {
  let time_string = case
    string.starts_with(value, "T"),
    string.starts_with(value, "t")
  {
    True, _ | _, True -> string.drop_left(value, 1)
    _, _ -> value
  }

  let time_string = string.replace(time_string, ":", "")

  use #(time_string, milli_seconds_result) <- result.then(case
    string.split(time_string, "."),
    string.split(time_string, ",")
  {
    [_], [_] -> {
      Ok(#(time_string, Ok(0)))
    }
    [time_string, milli_seconds_string], [_]
    | [_], [time_string, milli_seconds_string] -> {
      Ok(#(
        time_string,
        milli_seconds_string
          |> string.slice(0, 3)
          |> string.pad_right(3, "0")
          |> int.parse,
      ))
    }
    _, _ -> Error(Nil)
  })

  case milli_seconds_result {
    Ok(milli_seconds) -> {
      use time_of_day <- result.then(parse_time_section(time_string))
      let assert [hour, minute, second] = time_of_day

      Ok(#(TimeOfDay(hour, minute, second, milli_seconds), "Z"))
    }
    Error(Nil) -> Error(Nil)
  }
}

/// the naive format is the same as ISO8601 except that it does not contain the offset
pub fn to_naive(value: Time) -> String {
  let #(#(year, month, day), #(hour, minute, second, milli_second), _) =
    to_parts(value)

  int.to_string(year)
  <> "-"
  <> {
    month
    |> int.to_string
    |> string.pad_left(2, "0")
  }
  <> "-"
  <> {
    day
    |> int.to_string
    |> string.pad_left(2, "0")
  }
  <> "T"
  <> {
    hour
    |> int.to_string
    |> string.pad_left(2, "0")
  }
  <> ":"
  <> {
    minute
    |> int.to_string
    |> string.pad_left(2, "0")
  }
  <> ":"
  <> {
    second
    |> int.to_string
    |> string.pad_left(2, "0")
  }
  <> "."
  <> {
    milli_second
    |> int.to_string
    |> string.pad_left(3, "0")
  }
}

/// accepts fromats similar to the ones listed for `parse` except that there shoundn't be any offset information
pub fn from_naive(value: String) -> Result(Time, Nil) {
  let value = string.trim(value)

  use #(day_string, time_string) <- result.then(case
    string.split(value, "T"),
    string.split(value, "t"),
    string.split(value, " ")
  {
    [day_string, time_string], _, _
    | _, [day_string, time_string], _
    | _, _, [day_string, time_string] -> Ok(#(day_string, time_string))
    [_], [_], [_] -> Ok(#(value, "00"))
    _, _, _ -> Error(Nil)
  })

  let day_string = string.trim(day_string)
  let time_string = string.trim(time_string)

  let time_string = string.replace(time_string, ":", "")
  use #(time_string, milli_seconds_result) <- result.then(case
    [string.split(time_string, "."), string.split(time_string, ",")]
  {
    [[_], [_]] -> Ok(#(time_string, Ok(0)))
    [[time_string, milli_seconds_string], [_]]
    | [[_], [time_string, milli_seconds_string]] ->
      Ok(#(
        time_string,
        milli_seconds_string
          |> string.slice(0, 3)
          |> string.pad_right(3, "0")
          |> int.parse,
      ))

    _ -> Error(Nil)
  })

  case milli_seconds_result {
    Ok(milli_seconds) -> {
      use day <- result.then(parse_date_section(day_string))
      let assert [year, month, date] = day

      use time_of_day <- result.then(parse_time_section(time_string))
      let assert [hour, minute, second] = time_of_day

      from_parts(
        #(year, month, date),
        #(hour, minute, second, milli_seconds),
        "Z",
      )
    }

    Error(Nil) -> Error(Nil)
  }
}

/// see [here](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Date)
pub fn to_http(value: Time) -> String {
  let assert Ok(value) = set_offset(value, "Z")
  let #(#(year, _, day), #(hour, minute, second, _), _) = to_parts(value)
  let short_weekday = short_string_weekday(value)
  let short_month = short_string_month(value)

  short_weekday
  <> ", "
  <> {
    day
    |> int.to_string
    |> string.pad_left(2, "0")
  }
  <> " "
  <> short_month
  <> " "
  <> int.to_string(year)
  <> " "
  <> {
    hour
    |> int.to_string
    |> string.pad_left(2, "0")
  }
  <> ":"
  <> {
    minute
    |> int.to_string
    |> string.pad_left(2, "0")
  }
  <> ":"
  <> {
    second
    |> int.to_string
    |> string.pad_left(2, "0")
  }
  <> " GMT"
}

/// like `to_http` but assumes the offset in the DateTime value instead of `GMT`
pub fn to_http_with_offset(value: Time) -> String {
  let #(#(year, _, day), #(hour, minute, second, _), offset) = to_parts(value)
  let short_weekday = short_string_weekday(value)
  let short_month = short_string_month(value)

  let offset = case offset {
    "Z" -> "GMT"
    _ -> offset
  }

  short_weekday
  <> ", "
  <> {
    day
    |> int.to_string
    |> string.pad_left(2, "0")
  }
  <> " "
  <> short_month
  <> " "
  <> int.to_string(year)
  <> " "
  <> {
    hour
    |> int.to_string
    |> string.pad_left(2, "0")
  }
  <> ":"
  <> {
    minute
    |> int.to_string
    |> string.pad_left(2, "0")
  }
  <> ":"
  <> {
    second
    |> int.to_string
    |> string.pad_left(2, "0")
  }
  <> " "
  <> offset
}

/// see [here](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Date)
///
/// also supports other similar formats:
///
///   - `Tue, 01-Nov-2016 08:49:37 GMT`
///
///   - `Tue, 01 Nov 2016 08:49:37 +0630`
///
///   - `Tue, 01-November-2016 08:49:37 Z`
///
///   - `Tuesday, 01-Nov-2016 08:49:37 +330`
///
///   - `Tuesday, 01 November 2016 08:49:37 +06:30`
pub fn from_http(value: String) -> Result(Time, Nil) {
  let value = string.trim(value)
  use #(weekday, rest) <- result.then(string.split_once(value, ","))

  use <- bool.guard(
    !list.any(weekday_strings, fn(weekday_item) {
      let strings = weekday_item.1
      strings.0 == weekday || strings.1 == weekday
    }),
    Error(Nil),
  )

  let rest = string.trim(rest)
  let assert Ok(whitespace_pattern) = regex.from_string(space_regex <> "+")
  case regex.split(whitespace_pattern, rest) {
    [day_string, month_string, year_string, time_string, offset_string] -> {
      let time_string = string.replace(time_string, ":", "")
      case
        int.parse(day_string),
        list.index_map(month_strings, fn(month, index) {
          let strings = month.1
          #(index, strings.0, strings.1)
        })
        |> list.find(fn(month) {
          month.1 == month_string || month.2 == month_string
        }),
        int.parse(year_string),
        parse_time_section(time_string)
      {
        Ok(day), Ok(#(month_index, _, _)), Ok(year), Ok([hour, minute, second]) ->
          case
            from_parts(
              #(year, month_index + 1, day),
              #(hour, minute, second, 0),
              case offset_string {
                "GMT" -> "Z"
                _ -> offset_string
              },
            )
          {
            Ok(value) -> {
              let correct_weekday = string_weekday(value)
              let correct_short_weekday = short_string_weekday(value)

              case
                list.contains([correct_weekday, correct_short_weekday], weekday)
              {
                True -> Ok(value)
                False -> Error(Nil)
              }
            }
            Error(Nil) -> Error(Nil)
          }
        _, _, _, _ -> Error(Nil)
      }
    }

    [day_string, time_string, offset_string] ->
      case string.split(day_string, "-") {
        [day_string, month_string, year_string] -> {
          let time_string = string.replace(time_string, ":", "")
          case
            int.parse(day_string),
            list.index_map(month_strings, fn(month, index) {
              let strings = month.1
              #(index, strings.0, strings.1)
            })
            |> list.find(fn(month) {
              month.1 == month_string || month.2 == month_string
            }),
            int.parse(year_string),
            parse_time_section(time_string)
          {
            Ok(day),
              Ok(#(month_index, _, _)),
              Ok(year),
              Ok([hour, minute, second])
            ->
              case
                from_parts(
                  #(year, month_index + 1, day),
                  #(hour, minute, second, 0),
                  case offset_string {
                    "GMT" -> "Z"
                    _ -> offset_string
                  },
                )
              {
                Ok(value) -> {
                  let correct_weekday = string_weekday(value)
                  let correct_short_weekday = short_string_weekday(value)

                  case
                    list.contains(
                      [correct_weekday, correct_short_weekday],
                      weekday,
                    )
                  {
                    True -> Ok(value)
                    False -> Error(Nil)
                  }
                }
                Error(Nil) -> Error(Nil)
              }
            _, _, _, _ -> Error(Nil)
          }
        }
        _ -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

/// unix timestamps are the number of seconds that have elapsed since 00:00:00 UTC on January 1st, 1970
pub fn to_unix(value: Time) -> Int {
  case value {
    Time(t, _, _, _) -> t / 1_000_000
  }
}

/// unix timestamps are the number of seconds that have elapsed since 00:00:00 UTC on January 1st, 1970
pub fn from_unix(value: Int) -> Time {
  Time(value * 1_000_000, 0, option.None, option.None)
}

pub fn compare(a: Time, b: Time) -> order.Order {
  let Time(wall_time: wta, offset: _, timezone: _, monotonic_time: mta) = a
  let Time(wall_time: wtb, offset: _, timezone: _, monotonic_time: mtb) = b

  let #(ta, tb) = case mta, mtb {
    option.Some(ta), option.Some(tb) -> #(ta, tb)
    _, _ -> #(wta, wtb)
  }

  case ta == tb, ta < tb {
    True, _ -> order.Eq
    _, True -> order.Lt
    _, False -> order.Gt
  }
}

pub fn difference(a: Time, b: Time) -> duration.Duration {
  let Time(wall_time: wta, offset: _, timezone: _, monotonic_time: mta) = a
  let Time(wall_time: wtb, offset: _, timezone: _, monotonic_time: mtb) = b

  let #(ta, tb) = case mta, mtb {
    option.Some(ta), option.Some(tb) -> #(ta, tb)
    _, _ -> #(wta, wtb)
  }

  duration.Duration(ta - tb)
}

const string_to_units = [
  #("year", duration.Year),
  #("month", duration.Month),
  #("week", duration.Week),
  #("day", duration.Day),
  #("hour", duration.Hour),
  #("minute", duration.Minute),
  #("second", duration.Second),
]

/// you could say this is the opposite of `legible_difference`
///
/// ```gleam
/// > parse_relative(birl.now(), "8 minutes ago")
/// ```
pub fn parse_relative(origin: Time, legible_difference: String) {
  case string.split(legible_difference, " ") {
    ["in", amount_string, unit]
    | [amount_string, unit, "from now"]
    | [amount_string, unit, "later"]
    | [amount_string, unit, "ahead"]
    | [amount_string, unit, "in the future"]
    | [amount_string, unit, "hence"] -> {
      let unit = case string.ends_with(unit, "s") {
        False -> unit
        True -> string.drop_right(unit, 1)
      }

      use amount <- result.then(int.parse(amount_string))
      use unit <- result.then(list.key_find(string_to_units, unit))
      Ok(add(origin, duration.new([#(amount, unit)])))
    }

    [amount_string, unit, "ago"]
    | [amount_string, unit, "before"]
    | [amount_string, unit, "earlier"]
    | [amount_string, unit, "since"]
    | [amount_string, unit, "in the past"] -> {
      let unit = case string.ends_with(unit, "s") {
        False -> unit
        True -> string.drop_right(unit, 1)
      }

      use amount <- result.then(int.parse(amount_string))
      use unit <- result.then(list.key_find(string_to_units, unit))
      Ok(subtract(origin, duration.new([#(amount, unit)])))
    }

    _ -> Error(Nil)
  }
}

const units_to_string = [
  #(duration.Year, "year"),
  #(duration.Month, "month"),
  #(duration.Week, "week"),
  #(duration.Day, "day"),
  #(duration.Hour, "hour"),
  #(duration.Minute, "minute"),
  #(duration.Second, "second"),
]

pub fn legible_difference(a: Time, b: Time) -> String {
  case
    difference(a, b)
    |> duration.blur
  {
    #(_, duration.MicroSecond) | #(_, duration.MilliSecond) -> "just now"

    #(amount, unit) -> {
      let assert Ok(unit) = list.key_find(units_to_string, unit)
      let is_negative = amount < 0
      let amount = int.absolute_value(amount)

      let unit = case amount {
        1 -> unit
        _ -> unit <> "s"
      }

      case is_negative {
        True -> "in " <> int.to_string(amount) <> " " <> unit
        False ->
          amount
          |> int.absolute_value
          |> int.to_string
          <> " "
          <> unit
          <> " ago"
      }
    }
  }
}

pub fn add(value: Time, duration: duration.Duration) -> Time {
  let Time(wall_time: wt, offset: o, timezone: timezone, monotonic_time: mt) =
    value
  let duration.Duration(duration) = duration
  case mt {
    option.Some(mt) ->
      Time(
        wall_time: wt + duration,
        offset: o,
        timezone: timezone,
        monotonic_time: option.Some(mt + duration),
      )
    option.None ->
      Time(
        wall_time: wt + duration,
        offset: o,
        timezone: timezone,
        monotonic_time: option.None,
      )
  }
}

pub fn subtract(value: Time, duration: duration.Duration) -> Time {
  let Time(wall_time: wt, offset: o, timezone: timezone, monotonic_time: mt) =
    value
  let duration.Duration(duration) = duration
  case mt {
    option.Some(mt) ->
      Time(
        wall_time: wt - duration,
        offset: o,
        timezone: timezone,
        monotonic_time: option.Some(mt - duration),
      )
    option.None ->
      Time(
        wall_time: wt - duration,
        offset: o,
        timezone: timezone,
        monotonic_time: option.None,
      )
  }
}

pub fn weekday(value: Time) -> Weekday {
  case value {
    Time(wall_time: t, offset: o, timezone: _, monotonic_time: _) -> {
      let assert Ok(weekday) = list.at(weekdays, ffi_weekday(t, o))
      weekday
    }
  }
}

pub fn string_weekday(value: Time) -> String {
  case weekday(value) {
    Mon -> "Monday"
    Tue -> "Tuesday"
    Wed -> "Wednesday"
    Thu -> "Thursday"
    Fri -> "Friday"
    Sat -> "Saturday"
    Sun -> "Sunday"
  }
}

pub fn short_string_weekday(value: Time) -> String {
  case weekday(value) {
    Mon -> "Mon"
    Tue -> "Tue"
    Wed -> "Wed"
    Thu -> "Thu"
    Fri -> "Fri"
    Sat -> "Sat"
    Sun -> "Sun"
  }
}

pub fn month(value: Time) -> Month {
  let #(#(_, month, _), _, _) = to_parts(value)
  let assert Ok(month) = list.at(months, month - 1)
  month
}

pub fn string_month(value: Time) -> String {
  case month(value) {
    Jan -> "January"
    Feb -> "February"
    Mar -> "March"
    Apr -> "April"
    May -> "May"
    Jun -> "June"
    Jul -> "July"
    Aug -> "August"
    Sep -> "September"
    Oct -> "October"
    Nov -> "November"
    Dec -> "December"
  }
}

pub fn short_string_month(value: Time) -> String {
  case month(value) {
    Jan -> "Jan"
    Feb -> "Feb"
    Mar -> "Mar"
    Apr -> "Apr"
    May -> "May"
    Jun -> "Jun"
    Jul -> "Jul"
    Aug -> "Aug"
    Sep -> "Sep"
    Oct -> "Oct"
    Nov -> "Nov"
    Dec -> "Dec"
  }
}

/// can be used to create a time range starting from time `a` with step `s`
///
/// if `b` is `option.None` the range will be infinite
pub fn range(
  from a: Time,
  to b: option.Option(Time),
  step s: duration.Duration,
) -> iterator.Iterator(Time) {
  let assert Ok(range) = case b {
    option.Some(b) ->
      ranger.create(
        validate: fn(_) { True },
        negate_step: fn(duration) {
          let duration.Duration(value) = duration
          duration.Duration(-1 * value)
        },
        add: add,
        compare: compare,
      )(a, b, s)
    option.None ->
      ranger.create_infinite(
        validate: fn(_) { True },
        add: add,
        compare: compare,
      )(a, s)
  }
  range
}

pub fn set_timezone(value: Time, new_timezone: String) -> Result(Time, Nil) {
  case list.key_find(zones.list, new_timezone) {
    Ok(new_offset_number) -> {
      case value {
        Time(wall_time: t, offset: _, timezone: _, monotonic_time: mt) ->
          Time(t, new_offset_number * 1_000_000, option.Some(new_timezone), mt)
          |> Ok
      }
    }

    Error(Nil) -> Error(Nil)
  }
}

pub fn get_timezone(value: Time) -> option.Option(String) {
  let Time(_, _, timezone, _) = value
  timezone
}

/// use this to change the offset of a given time value.
///
/// some examples of acceptable offsets:
///
/// `"+330", "03:30", "-8:00","-7", "-0400", "03", "Z"`
pub fn set_offset(value: Time, new_offset: String) -> Result(Time, Nil) {
  use new_offset_number <- result.then(parse_offset(new_offset))
  case value {
    Time(wall_time: t, offset: _, timezone: timezone, monotonic_time: mt) ->
      Time(t, new_offset_number, timezone, mt)
      |> Ok
  }
}

pub fn get_offset(value: Time) -> String {
  let Time(_, offset, _, _) = value
  let assert Ok(offset) = generate_offset(offset)
  offset
}

pub fn set_day(value: Time, day: Day) -> Time {
  let #(_, time, offset) = to_parts(value)
  let Day(year, month, date) = day
  let assert Ok(new_value) = from_parts(#(year, month, date), time, offset)
  new_value
}

pub fn get_day(value: Time) -> Day {
  let #(#(year, month, day), _, _) = to_parts(value)
  Day(year, month, day)
}

pub fn set_time_of_day(value: Time, time: TimeOfDay) -> Time {
  let #(date, _, offset) = to_parts(value)
  let TimeOfDay(hour, minute, second, milli_second) = time
  let assert Ok(new_value) =
    from_parts(date, #(hour, minute, second, milli_second), offset)
  new_value
}

pub fn get_time_of_day(value: Time) -> TimeOfDay {
  let #(_, #(hour, minute, second, milli_second), _) = to_parts(value)
  TimeOfDay(hour, minute, second, milli_second)
}

@target(erlang)
/// calculates erlang datetime using the offset in the DateTime value
pub fn to_erlang_datetime(value: Time) -> #(#(Int, Int, Int), #(Int, Int, Int)) {
  let #(date, #(hour, minute, second, _), _) = to_parts(value)
  #(date, #(hour, minute, second))
}

@target(erlang)
/// calculates the universal erlang datetime regardless of the offset in the DateTime value
pub fn to_erlang_universal_datetime(
  value: Time,
) -> #(#(Int, Int, Int), #(Int, Int, Int)) {
  let assert Ok(value) = set_offset(value, "Z")
  let #(date, #(hour, minute, second, _), _) = to_parts(value)
  #(date, #(hour, minute, second))
}

@target(erlang)
/// calculates the DateTime value from the erlang datetime using the local offset of the system
pub fn from_erlang_local_datetime(
  erlang_datetime: #(#(Int, Int, Int), #(Int, Int, Int)),
) -> Time {
  let #(date, time) = erlang_datetime
  let offset_in_minutes = ffi_local_offset()

  let assert Time(wall_time, _, option.None, option.None) =
    unix_epoch
    |> set_day(Day(date.0, date.1, date.2))
    |> set_time_of_day(TimeOfDay(time.0, time.1, time.2, 0))

  let timezone = local_timezone()

  Time(
    wall_time,
    offset_in_minutes * 60_000_000,
    option.map(timezone, fn(tz) {
      case list.any(zones.list, fn(item) { item.0 == tz }) {
        True -> option.Some(tz)
        False -> option.None
      }
    })
      |> option.flatten,
    option.None,
  )
}

@target(erlang)
/// calculates the DateTime value from the erlang datetime in UTC
pub fn from_erlang_universal_datetime(
  erlang_datetime: #(#(Int, Int, Int), #(Int, Int, Int)),
) -> Time {
  let #(date, time) = erlang_datetime
  let assert Ok(new_value) =
    unix_epoch
    |> set_day(Day(date.0, date.1, date.2))
    |> set_time_of_day(TimeOfDay(time.0, time.1, time.2, 0))
    |> set_timezone("Etc/UTC")
  new_value
}

fn from_parts(
  date: #(Int, Int, Int),
  time: #(Int, Int, Int, Int),
  offset: String,
) -> Result(Time, Nil) {
  use offset_number <- result.then(parse_offset(offset))
  ffi_from_parts(#(date, time), offset_number)
  |> Time(offset_number, option.None, option.None)
  |> Ok
}

fn to_parts(value: Time) -> #(#(Int, Int, Int), #(Int, Int, Int, Int), String) {
  case value {
    Time(wall_time: t, offset: o, timezone: _, monotonic_time: _) -> {
      let #(date, time) = ffi_to_parts(t, o)
      let assert Ok(offset) = generate_offset(o)
      #(date, time, offset)
    }
  }
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
        1 -> {
          use hour <- result.then(int.parse(offset))
          Ok(sign * hour * 3600 * 1_000_000)
        }
        2 -> {
          use number <- result.then(int.parse(offset))
          case number < 14 {
            True -> Ok(sign * number * 3600 * 1_000_000)
            False ->
              Ok(sign * { number / 10 * 60 + number % 10 } * 60 * 1_000_000)
          }
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

fn parse_date_section(date: String) -> Result(List(Int), Nil) {
  use <- bool.guard(is_invalid_date(date), Error(Nil))

  case string.contains(date, "-") {
    True -> {
      let assert Ok(dash_pattern) =
        regex.from_string(
          "(" <> digit_regex <> "{4})(-(1[0-2]|0?[0-9]))?(-(3[0-1]|[1-2][0-9]|0?[0-9]))?",
        )

      case regex.scan(dash_pattern, date) {
        [regex.Match(_, [option.Some(major)])] -> [
          int.parse(major),
          Ok(1),
          Ok(1),
        ]

        [regex.Match(_, [option.Some(major), _, option.Some(middle)])] -> [
          int.parse(major),
          int.parse(middle),
          Ok(1),
        ]

        [
            regex.Match(
              _,
              [option.Some(major), _, option.Some(middle), _, option.Some(minor)],
            ),
          ] -> [int.parse(major), int.parse(middle), int.parse(minor)]

        _ -> [Error(Nil)]
      }
    }

    False ->
      parse_section(
        date,
        "(" <> digit_regex <> "{4})(1[0-2]|0?[0-9])?(3[0-1]|[1-2][0-9]|0?[0-9])?",
        1,
      )
  }
  |> list.try_map(function.identity)
}

fn parse_time_section(time: String) -> Result(List(Int), Nil) {
  use <- bool.guard(is_invalid_time(time), Error(Nil))

  parse_section(
    time,
    "(2[0-3]|1[0-9]|0?[0-9])([1-5][0-9]|0?[0-9])?([1-5][0-9]|0?[0-9])?",
    0,
  )
  |> list.try_map(function.identity)
}

fn is_invalid_date(date: String) -> Bool {
  date
  |> string.to_utf_codepoints
  |> list.map(string.utf_codepoint_to_int)
  |> list.any(fn(code) {
    case code {
      _ if code == 45 -> False
      _ if code >= 48 && code <= 57 -> False
      _ -> True
    }
  })
}

fn is_invalid_time(time: String) -> Bool {
  time
  |> string.to_utf_codepoints
  |> list.map(string.utf_codepoint_to_int)
  |> list.any(fn(code) {
    case code {
      _ if code >= 48 && code <= 58 -> False
      _ -> True
    }
  })
}

fn parse_section(
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

@target(erlang)
const weekdays = [Mon, Tue, Wed, Thu, Fri, Sat, Sun]

@target(javascript)
const weekdays = [Sun, Mon, Tue, Wed, Thu, Fri, Sat]

@target(nix)
const weekdays = [Sun, Mon, Tue, Wed, Thu, Fri, Sat]

const months = [Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec]

const weekday_strings = [
  #(Mon, #("Monday", "Mon")),
  #(Tue, #("Tuesday", "Tue")),
  #(Wed, #("Wednesday", "Wed")),
  #(Thu, #("Thursday", "Thu")),
  #(Fri, #("Friday", "Fri")),
  #(Sat, #("Saturday", "Sat")),
  #(Sun, #("Sunday", "Sun")),
]

const month_strings = [
  #(Jan, #("January", "Jan")),
  #(Feb, #("February", "Feb")),
  #(Mar, #("March", "Mar")),
  #(Apr, #("April", "Apr")),
  #(May, #("May", "May")),
  #(Jun, #("June", "Jun")),
  #(Jul, #("July", "Jul")),
  #(Aug, #("August", "Aug")),
  #(Sep, #("September", "Sep")),
  #(Oct, #("October", "Oct")),
  #(Nov, #("November", "Nov")),
  #(Dec, #("December", "Dec")),
]

@external(erlang, "birl_ffi", "now")
@external(javascript, "./birl_ffi.mjs", "now")
@external(nix, "./birl_ffi.nix", "now")
fn ffi_now() -> Int

@external(erlang, "birl_ffi", "local_offset")
@external(javascript, "./birl_ffi.mjs", "local_offset")
@external(nix, "./birl_ffi.nix", "local_offset")
fn ffi_local_offset() -> Int

@external(erlang, "birl_ffi", "monotonic_now")
@external(javascript, "./birl_ffi.mjs", "monotonic_now")
@external(nix, "./birl_ffi.nix", "monotonic_now")
fn ffi_monotonic_now() -> Int

@external(erlang, "birl_ffi", "to_parts")
@external(javascript, "./birl_ffi.mjs", "to_parts")
fn ffi_to_parts(
  timestamp: Int,
  offset: Int,
) -> #(#(Int, Int, Int), #(Int, Int, Int, Int)) {
  // fallback for Nix
  let timestamp = timestamp + offset
  // microseconds => days
  // (with adjustment to handle negative days)
  let microseconds_per_day = 1000 * 1000 * 3600 * 24
  let days = case timestamp >= 0 {
    True -> timestamp / microseconds_per_day
    False -> {timestamp - {microseconds_per_day - 1}} / microseconds_per_day
  }

  // From http://howardhinnant.github.io/date_algorithms.html (`civil_from_days`)
  let #(year, month, date) = {
    let days = days + 719_468
    let era = case days >= 0 {
      True -> days / 146_097
      False -> { days - 146_096 } / 146_097
    }
    // [0, 146096]
    let day_of_era = days - era * 146_097

    // [0, 399]
    let year_of_era =
      {
        day_of_era
        - day_of_era
        / 1460
        + day_of_era
        / 36_524
        - day_of_era
        / 146_096
      }
      / 365

    let year = year_of_era + era * 400

    // [0, 365]
    let day_of_year =
      day_of_era - { 365 * year_of_era + year_of_era / 4 - year_of_era / 100 }
    // [0, 11]
    let unconverted_month = { 5 * day_of_year + 2 } / 153
    // [1, 31]
    let date = day_of_year - { 153 * unconverted_month + 2 } / 5 + 1
    // [1, 12]
    let month = case unconverted_month < 10 {
      True -> unconverted_month + 3
      False -> unconverted_month - 9
    }

    let month_modifier = case month <= 2 {
      True -> 1
      False -> 0
    }
    let year = year + month_modifier

    #(year, month, date)
  }

  let remaining_microseconds = timestamp - days * microseconds_per_day
  let remaining_milliseconds = remaining_microseconds / 1000
  let hours = remaining_milliseconds / { 1000 * 3600 }
  let minutes = { remaining_milliseconds - hours * 1000 * 3600 } / { 1000 * 60 }
  let seconds =
    { remaining_milliseconds - hours * 1000 * 3600 - minutes * 1000 * 60 }
    / 1000
  let milliseconds =
    remaining_milliseconds
    - hours
    * 1000
    * 3600
    - minutes
    * 1000
    * 60
    - seconds
    * 1000

  #(#(year, month, date), #(hours, minutes, seconds, milliseconds))
}

@external(erlang, "birl_ffi", "from_parts")
@external(javascript, "./birl_ffi.mjs", "from_parts")
fn ffi_from_parts(
  parts: #(#(Int, Int, Int), #(Int, Int, Int, Int)),
  offset: Int,
) -> Int {
  // fallback for Nix
  let #(#(year, month, day), #(hour, minute, second, milliseconds)) = parts

  // From http://howardhinnant.github.io/date_algorithms.html (`days_from_civil`)
  // Calculate the days since Jan 1, 1970
  let days_from_civil = {
    let year = case month <= 2 {
      True -> year - 1
      False -> year
    }

    // The civil calendar repeats itself every 400 years.
    let era = case year >= 0 {
      True -> year / 400
      False -> { year - 399 } / 400
    }

    // [0, 399] (euclidean remainder)
    let year_of_era = year - era * 400

    // [0, 365]
    let day_of_year = case month > 2 {
      True -> { 153 * { month - 3 } + 2 } / 5 + day - 1
      False -> { 153 * { month + 9 } + 2 } / 5 + day - 1
    }

    // [0, 146096]
    let day_of_era =
      year_of_era * 365 + year_of_era / 4 - year_of_era / 100 + day_of_year

    // (year, month, day) => days since Jan 1, 1970
    era * 146_097 + day_of_era - 719_468
  }

  // days since Jan 1, 1970 => seconds since Jan 1, 1970
  let date_as_seconds = days_from_civil * 3600 * 24

  // (hour, min, sec) => seconds
  let converted_time = hour * 3600 + minute * 60 + second

  // seconds since Jan 1, 1970
  let converted_seconds = date_as_seconds + converted_time

  // microseconds since Jan 1, 1970 - offset
  { converted_seconds * 1000 + milliseconds } * 1000 - offset
}

@external(erlang, "birl_ffi", "weekday")
@external(javascript, "./birl_ffi.mjs", "weekday")
fn ffi_weekday(timestamp: Int, offset: Int) -> Int {
  // fallback for Nix
  let timestamp = timestamp + offset
  let days = timestamp / { 1000 * 1000 * 3600 * 24 }

  // From http://howardhinnant.github.io/date_algorithms.html#weekday_from_days
  // [0, 6]
  case days >= -4 {
    True -> {days + 4} % 7
    False -> {days + 5} % 7 + 6
  }
}

@external(erlang, "birl_ffi", "local_timezone")
@external(javascript, "./birl_ffi.mjs", "local_timezone")
@external(nix, "./birl_ffi.nix", "local_timezone")
fn local_timezone() -> option.Option(String)
