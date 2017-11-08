e OpenWeatherMap

The concept of Elixir **processes** is one of the most important to
understand, and it rightly deserves it own manual. Processes are the
fundamental units of concurrency in Elixir, In fact the Erlang VM
supports up to 134 million (!) processes, which would cause all of your
CPUs to happily light up. (I always get a warm, fuzzy feeling when I
know I'm getting my money's worth from my hardware.) The processes
created by the Erlang VM are independent of the operating system;
they're lighter weight and take mere microseconds to created.

We'll build a simple programm that reports the temperature of a given
city/state/country. But first, let's learn about the Actor concurrency
model.

**Actor concurrency model**

Erlang (and therefore Elixir) uses the Actor concurrency model. This
means the following:

* Each **actor** is a process.
* Each process performs a **specific task**.
* To tell a process to do something, you need to **send it a message**.
  The process can reply by **sending back another message**.
* The kinds of messages the process can act on are specific to the
  process itself. In other words, messages are **pattern-matched**.
* Other than that, processes **don't share any information** with other
  processes.

If all ttis seems fuzzy, fret not. If you've done any object-oriented
programming, you'll find that processes resemble objects in many ways.
You could even argue that this is a pure form of object-orientation.

Here's one way to think about actors. Actors are like people. We
communication with each other by talking . For example, suppose my wife
tells me to do the dishes. Of course, I respond by doing the dishes -
I'm a good husband. But if my wife tells me to eat my vegetables, she'll
be ignored - I won't respond to that. In effect, I'm choosing to respond
only to certain kinds of messages. In addition, I don't know what goes
on inside her head, and she doesn't know what goes on inside my head. As
you'll soon see, the actor concurrency model acts the same way: it
responds only to certain kinds of messages.

**Building a weather application**

Conceptually, the application you'll create in this manual is simple
(see figure bottom). The first version accepts a single argument
containing a location, and it reports the temperature in degrees
Celsius. That involves making a HTTP request to an external weather
service and parsing the JSON response to extract the temperature.

Making a single request is trivial. But what happens if you want to find
out the temperatures in 100 cities simultaneously? Assuming that each
request takes 1 second, are you going to wait 100 seconds? Obviously
not! You'll see how to make concurrent requests so you can get the
results as soon as possible.

One of the properties of concurrency is that you never know the order of
the responses. For example, imagine thet you pass in a list of cities in
alphabetical order. The responses you get back are in no way guaranteed
to be in the same order.

How can you ensure that the responses are in the correct order? Read on.
dear reader - you begin your meteorological adventures in Elixir next.

```bash

                      ╔═══════════════════╗
                      ║   Weather APIs    ║
                      ╚══════╦═════╦══════╝
                             ║     ║
                             ║     ║
                             ║     ║
       "Singapore"    ╔══════╩═════╩══════╗   `{:ok, 28 °C}`
   <──────────────────╫   Weather Actor   ╫───────────────────>
       1. Request     ╚═══════════════════╝

               Weather actor handling a single request
```

Let's start with a native version of the weather application. It will
contain all the logic needed to make a request, parse the response, and
return the result, but no concurrency will be involved. By the end of
this iteration, you'll know how to do the following:

* Install and use third-party libraries using mix
* Make a HTTP request to a third-party APIs
* Parse a JSON response using pattern matching
* Use pipe to facilitate data transformation

This is the first nontrivial program you'll work thought in this manual.
But no worries: I'll guide you every step of the day.

```elixir
mix new open_weather_map

# let's add two dependencies by modifying the `deps` function
# to look like this: mix.exs
defp deps do
  [
    {:httpoison, "~> 0.13.0"},
    {:json, "~> "1.0.2"}

  ]
end

mix deps.get
mix deps.update --all
mix deps.get

# create files `config/dev.exs config/prod.exs config/test.exs`

# edit `config/config.exs`
use Mix.Config
import_config "#{Mix.env}.exs"

# edit `config/dev.exs`
use Mix.Config

config :open_weather_map,
  http: [port: 8880],
  debug_errors: true,
  api_key: "c61d49cd0d1d22afc541df82fd48fbdb"

# edit `config/prod.exs`
use Mix.Config

config :open_weather_map,
  http: [port: 8882],
  api_key: "c61d49cd0d1d22afc541df82fd48fbdb"

# edit `config/test.exs`
use Mix.Config

config :open_weather_map,
  http: [port: 8881],
  debug_errors: true,
  api_key: "c61d49cd0d1d22afc541df82fd48fbdb"

mix compile
mix test
iex -S mix
```

Before you create the worker, you need to obtain an API key from the
third-party weather service OpenWeatherMap.
Head over to `http://openweathermap.org` to create an account. When you
finish, you'll see that your API key has been created for you.

Now you can get into the implementation details of the worker. The
worker's job is to fetch the temperature of a given location from
OpenWeatherMap and parse the results. Create a `lib/worker.ex` file in
the lib directory, and enter the code in the following listing in it.

```elixir
defmodule OpenWeatherMap.Worker do
  def temperature_of(location) do
    result = url_for(location)
              |> HTTPoison.get
              |> parse_response

    case result do
      {:ok, temp} ->
        "#{location}: #{temp}°C"
      :error ->
        "#{location} not found"
    end
  end

  defp url_for(location) do
    location = URI.encode(location)
    "http://api.openweathermap.org/data/2.5/weather?q=#{location}&appid=#{apikey()}"
  end

  defp parse_response({:ok, %HTTPoison.Response{body: body, status_code: 200}}) do
    body |> JSON.decode! |> compute_temperature
  end

  defp parse_response(_) do
    :error
  end

  defp compute_temperature(json) do
    try do
      temp = (json["main"]["temp"] - 273.15) |> Float.round(1)
      {:ok, temp}
    rescue
      _ -> :error
    end
  end

  defp apikey do
    Application.fetch_env!(:open_weather_map, :api_key)
  end
end
```

Don't be alarmed if you don't entirely understand what's going on: we'll
go through the program bit by bit. First. let's see how to run this
program fron `iex`. From the project root directory, launch `iex` like
so: `iex -S mix`.

If this is the first time you've run that command, you'll notice a list
of dependencies being compiled. You won't see this the next time you run
`iex` unless you modify the dependencies.

Now let's find out the temperature of one of the coldest places in the
world:

```elixir
OpenWeatherMap.Worker, temperature_of "Kiev, Ukraine"
#=> "Kiev, Ukraine: 5.0°C"
```

Just for kicks, let's try another:

```elixir
Open WeatherMap.Worker.temperature_of "Snag, Yukon, Canada"
#=> "Snag, Yukon, Canada: -7.0°C"
```

What happens when you give a nonsensical location?

```elixir
OpenWeatherMap.Worker.temperature_of "Omicron Persei 8"
#=> "Omicron Persei 8 not found"
```

Now that's you've seen the worker in action, let's take a closer look at
how it works, beginning with the `temperature_of/1` function:

```elixir
defmodule OpenWeatherMap.Worker do
  def temperature_of(location) do
    result = url_for(location)  # Data transformation from
              |> HTTPoison.get  # URL to HTTP response to
              |> parse_response # parsing that response

    case result do
      {:ok, temp} ->              # A successfully parsed response
        "#{location}: #{temp}°C"  # return the temperature and location
      :error ->                   # Otherwise, an error
        "#{location} not found"   # message is returned.
    end
  end
end
```

The most important line in the function is

```elixir
result = location |> url_for |> HTTPoison.get |> parse_response
```

Without using the pipe operator, you'd have to write the function like
so: `result = parse_response(HTTPoison.get(url_for(location)))`.

`location |> url_for` constructs the URL that's used to call the weather
API. For example, the URL for Singapure is as follows (substitute your
own API key for `<APIKEY>`):

```elixir
"http://api.openweathermap.org/data/2.5/weather?q=Singapore&appid=<APIKEY>"
```

Once you have the URL, you can use `httpoison`, an HTTP client, to make
a `GET` request: `location |> url_for |> HTTPoison.get`.

If you try that URL in your browser, you'll get something like this
(I've trimmed the JON for brevity):

```
{
  ...
  "main": {
    "temp": 299.86,
    "temp_min": 299.86,
    "temp_max": 299.86,
    "pressure": 1028.96,
    "sea_level": 1029.64,
    "grnd_level": 1028.96,
    "hunidity": 100
  },
  ...
}

```

Let's take a closer look at the response from the HTTP client. Try this
in `iex`, too. (If you exited `iex`, remembern to use `iex -S mix` so
that the dependencies - such as `httpoison` - are loaded properly.) Use
the URL for Singapore's temperature:

```elixir
HTTPoison.get
"http://api.openweathermap.org/data/2.5/weather?q=Singapore&appid=<APIKEY>"
```

Take a look at the results:

```elixir
{:ok,
%HTTPoison.Response{body:
"{\"coord\":{\"lon\":103.85,\"lat\":1.29},\"weather\":[{\"id\":800,\"main\":\"Clear\",\"description\":\"clear
sky\",\"icon\":\"01n\"}],\"base\":\"stations\",\"main\":{\"temp\":299.39,\"pressure\":1007,\"humidity\":88,\"temp_min\":298.15,\"temp_max\":300.15},\"visibility\":10000,\"wind\":{\"speed\":1,\"deg\":30},\"clouds\":{\"all\":0},\"dt\":1509991200,\"sys\":{\"type\":1,\"id\":8143,\"message\":0.0042,\"country\":\"SG\",\"sunrise\":1509921974,\"sunset\":1509965411},\"id\":1880252,\"name\":\"Singapore\",\"cod\":200}",
  headers: [{"Server", "openresty"}, {"Date", "Mon, 06 Nov 2017 18:38:01
GMT"},
   {"Content-Type", "application/json; charset=utf-8"},
   {"Content-Length", "443"}, {"Connection", "keep-alive"},
   {"X-Cache-Key", "/data/2.5/weather?q=singapore"},
   {"Access-Control-Allow-Origin", "*"},
   {"Access-Control-Allow-Credentials", "true"},
   {"Access-Control-Allow-Methods", "GET, POST"}],
  request_url:
"http://api.openweathermap.org/data/2.5/weather?q=Singapore&appid=c61d49cd0d1d20afc541df82fd48fbdb",
  status_code: 200}}
```

You've just seen several of variations of what `HTTPoison.get(url)`
can return. The happy path returns a pattern that resembles this:

```elixir
{:ok, %HTTPoison.Response{status_code: 200, body,: content}}}
```

This pattern conveys the following inforamtion:

* This is a two-element tuple.
* The first element of the tuple is an `:ok` atom, followed by a
  structure that represents the response.
* The response is of type `HTTPoison.Response` and contains at least
  two fields.
* The value of `status_code` is 200, which represents a successful
  `HTTP GET` request.
* The value of `body` is captures in `content`.

As you can see, pattern matching is incredibly succinct and s a
beautiful way to express what you want. Similarly, an error tuple has
the following pattern: `{:error, %HTTPoison.Error{reason: reason}}`.

Let's do the same analysis here:

* This is a two-element tuple.
* The first element of the tuple is an `:error` atom, followed by a
  structure that represents the rror.
* The response is of type `HTTPoison.Error` and contains at least one
  field, `reason`.
* The reason for the error is captured in  `reason`.

With all that in mind, let's take a look at the `parse_response/1`
function:

```elixir
defp parse_response({:ok, %HTTPoison.Response{body: body, status_code: 200}}) do
  body |> JSON.decode! |> compute_temperature
end

defp parse_response(_) do
  :error
end
```

This specifies two versions of `parse_response/1`. The first version
matches a successful `GET` request because you're matching a response
of type `HTTPoison.Response` and also making sure `status_code` is 200.
You treat any other kind of response as an error. Let's take a closer
look now at the first version of `parse_response/1`:

```elixir
defp parse_response({:ok, %HTTPoison.Response{body: body, status_code: 200}}) do
  ...
end
```

On a successful patternmatch, the string representation of the JSON is
captured in the body variable. To turn it into real JSON you need to
decode it: `body | JSON.decode!`

You then pass this JSON into the `compute_temperature/1` function.
Here's the function again:

```elixir
defp compute_temperature(json) do
  try do
    temp = (json["main"]["temp"] - 273.15) |> Float.round(1)
    {:ok, temp}
  rescue
    _ -> :error
  end
end
```

You wrap the computation in a `try ... rescue ... end` block, where you
attempt to retrieve the temperature from the given JSON and then perform
some arithmetic: you subtract `273.15` because the API provides the
results in kelvins. You also round off the temperature to one decimal
place. At any of these points, an error may occur. If it does, you want
the return to be an `:error` atom. Otherwise, a two-element tuple
containing `:ok` as the first element and the temperature is returned.
Having return values of different shapes is useful because code that
calls this this function can, for example, easily pattern-match on both
success and failure cases. You'll se many more examples that take
advantage of pattern matching in the following sections.

What happens if the HTTP `GET` response doesn't match the first pattern?
That's the job of the second `parse_response/1` function:

```elixir
defp parse_response(_) do
  :error
end
```

Here, any response other than a successfuk one is treated as an error.
That's basically it! You should now have a better understanding of how
the worker works. Let's look at how processes are created in Elixir.

### Nov 2017 Oleg G.Kapranov
