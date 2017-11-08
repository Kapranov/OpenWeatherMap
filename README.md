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

**Creating processes for concurrency**

Let's imagine you have a list of cities for which you want to get
temperatures:

```elixir
cities = ["Singapore", "Monaco", "Macau", "Hong Kong", "Kiev"]
```

You send the requests to the worker, one at a time:

```elixir
cities |> Enum.map(fn city ->
  OpenWeatherMap.Worker.temperature_of(city)
end)
```

This results in the following:

```elixir
["Singapore", "Monaco", "Macau", "Hong Kong", "Kiev"]
[
  "Singapore: 27.4°C",
  "Monaco: 8.4°C",
  "Macau: 23.1°C",
  "Hong Kong: 23.7°C",
  "Kiev: 3.0°C"
]
```

The problem with this approach is that it's wasteful. As the size of the
list grows, so will the time you have to wait for all the responses to
complete. The next request will be processed only when the previous one
has completed (see figure). You can do better.

Without concurrency, the next request has to wait for the previous one
to complete. This is inefficient.

```bash
                ╔═══════════════════╗
                ║        Cloud      ║
                ╚═══════╦═════╦═════╝
    Singapore   ╔═══════╩═════╩═════╗ `{:ok, 27.4°C}`
───────────────>║  Weather actor #1 ╫───────────────>
                ╚═══════════════════╝
                ╔═══════════════════╗
                ║        Cloud      ║
                ╚═══════╦═════╦═════╝
     Monaco     ╔═══════╩═════╩═════╗`{:ok, 8.4°C}`
───────────────>║  Weather actor #2 ╫───────────────>
                ╚═══════════════════╝
                ╔═══════════════════╗
                ║        Cloud      ║
                ╚═══════╦═════╦═════╝
     Macau      ╔═══════╩═════╩═════╗`{:ok, 23.1°C}`
───────────────>║  Weather actor #3 ╫───────────────>
                ╚═══════════════════╝
                ╔═══════════════════╗
                ║        Cloud      ║
                ╚═══════╦═════╦═════╝
   Hong Kong    ╔═══════╩═════╩═════╗`{:ok, 23.7°C}`
───────────────>║  Weather actor #4 ╫───────────────>
                ╚═══════════════════╝
                ╔═══════════════════╗
                ║        Cloud      ║
                ╚═══════╦═════╦═════╝
      Kiev      ╔═══════╩═════╩═════╗`{:ok, 3°C}`
───────────────>║  Weather actor #5 ╫───────────────>
                ╚═══════════════════╝

|───────────────────────────────────────────────────────────────>
                                Time

Without concurrency, the next request has to wait for
the previous one to complete. This is inefficient
```

It's important to realize thet requests don't depend on each other. In other
words, you can package each call to `OpenWeatherMap.Worker.temperature__of/1`
in a process. Let's teach the worker how to respond to messages. First, add
the `loop/0` function to `lib/worker.ex` in the next listing.

```elixir
def loop do
  receive do
    {sender_pid, location} ->
      send(sender_pid, {:ok, temperature_of(location)})
    _ ->
      IO.puts "don't know how to process this message"
  end
  loop
end

defp temperature_of(location) do
  result = url_for(location)
    |> HTTPoison.get
    |> parse_response

  case result do
    {:ok, temp} ->
      "#{location}: #{temp}°C"
    :error
      "#{location} not found"
  end
end
```

Before we go into the details, let's play around with this. If you
already have `iex` open, you can reload the module:
`r(OpenWeatherMap.Worker)`

Otherwise, run `iex -S mix` again. Create a process that runs the
worker's `loop` function:

```elixir
pid = spawn(OpenWeatherMap, :loop, [])
```

The built-in `spawn` function creates a process. There are two
variations of `spawn`. The first version takes a single function as a
parameter; the second takes a module, a symbol representing the function
name, and a list of arguments. Both versions return a process `id (pid)`

**Receiving messages**

A pid is a reference to a process, much as in object-oriented
programming the result of initializing an object is a reference to that
object. With the pid, you can send the process message. The kinds of
messages the process can receive are defined tin the receive block:

```elixir
receive do
  {sender_pid, location} ->
    send(sender_pid, {:ok, temperature_of(location)})
  _ ->
    IO.puts "don't know how to process this message"
end
```

Messages are pattern-matched from top to bottom. In this case, if the
incoming message is a two-element tuple, then the body will be executed.
Any other message will be pattern-matched in the second pattern.

What would happen if you wrote the previous code with the function
clauses swapped?

```elixir
receive do
  _ -> # Matches any message!
    IO.puts "don't know how to progress this message"
  {sender_pid, location} ->
    send(sender_pid, {:ok, temperature_of(location)})
end
```

If you try to run this Elixir helpfully warns you:

```elixir
lib/worker.ex:7: warning: this clause cannot match because a previous
```

In other words, `{sender_id, location}` will never be matched because
the match-all operator `(_)`, as it name suggests, will greedily match
ecery single message that comes its way.

In general, it's good practice to have the match-all case as the last
message to be matched. This is because unmatched messages are kept in
the mailbox. Therefore, it's possible to make the VM run out of memory
by repeatedly sending messages to a process that doesn't handle
unmatched  messages.

**Sending Messages**

Messages are sent using the built-in `send/2` function. The first
argument is the pid of the process you want to send the message to. The
second argument is the actual message:

```elixir
receive do
  # The incoming message contains the sender pid and location
  {sender_id, location} ->
    send(sender_id, {:ok, temperature_of(location)})
end
```
Here's, you're sending the result of the request to `sender_pid`. Where
do you get `sender_pid`? From the incoming message, of course! You
expect the incoming message to consist of the sender's pid and the
location. Putting in the sender's pid (or any prosecc id, for that
matter) is like putting a return address on an envelope: it gives the
recipient a place to reply to.

Let's send the process you created earlier a message:

```elixir
send(pid, {self, "Singapore"})
```
Here's the result: `{#PID<0.177.0>, "Singapore"}`

Wait - order than the return result, nothing else happened! Let's break
it down. The first thing to note is that the result of `send/2` is
alwais the message. The second thing is that `send/2` always returns
immediately. In order words, `send/2` is like fire-and-forget. Taht
explains how you got the result, because again, the result of `send/2`
is the message. But what about why you aren't getting back any
temperatures?

What did you pass into the message payload as the sender pid? `self`!
What is `self`, exactly? `self` is the pid of the calling process. In
this case, it's the pid of the `iex` shell session. You're effectively
telling the worker to send all replies to the shell session. To get back
responses from the shell session, you can use the built-in `flush/0`
function: `flush #=> {:ok, "Singapore: 26.2°C"} :ok`.

`flush/0` clears out all the messages that were sent to the shell and
prints them out. Therefore, the next time you do a `flush`, you'll only
get the `:ok` atom. Let's see this in action. Once again, you have a
list of cities:

```elixir
cities = ["Singapore", "Monaco", "Hong Kong", "Macau", "Kiev"]
```

You iterate through each city, and in each iteration, you spawn a new
worker. Using the pid of the new worker, you send the worker process a
two-element tuple as a message containing the return address (the `iex`
shell session) and the city:

```elixir
cities |> Enum.each(fn city ->
  pid = spawn(OpenWetherMap.Worker, :loop, [])
  send(pid, {self, city})
end)
```

Now, let's flush the messages:

```elixir
flush

#=> {:ok, "Monaco: 13.4°C"}
    {:ok, "Singapore: 26.2°C"}
    {:ok, "Kiev: 2.3°C"}
    {:ok, "Hong Kong: 22.9°C"}
    {:ok, "Macau: 23.0°C"}
    :ok
```

Awesome! You finally got back results. Notice that they aren't in any
particular order. That's because the response that completed first sent
its reply back to the sender as soon as it was finished (see figure
bottom). If you run the iteration again? you'll probably get the results
in a different order.

Look at the `loop` function again. Notice that's `recursive` - it calls
itself after a message has been processed:

```elixir
def loop do
  receive do
    {sender_pid, location} ->
      send(sender_pid, {:ok, temperature_of(location)})
    _ ->
      send(sender_pid, "Unknow message")
  end
  loop() # recursive call to loop
end
```

```bash
                ╔═══════════════════╗
                ║        Cloud      ║
                ╚═══════╦═════╦═════╝
    Singapore   ╔═══════╩═════╩═════╗ `{:ok, 27.4°C}`
───────────────>║  Weather actor #1 ╫─────────────────────────>
                ╚═══════════════════╝                          |
                ╔═══════════════════╗                          |
                ║        Cloud      ║                          |
                ╚═══════╦═════╦═════╝                          |
     Monaco     ╔═══════╩═════╩═════╗ `{:ok, 8.4°C}`           |
───────────────>║  Weather actor #2 ╫────────────────>         |
                ╚═══════════════════╝                 |        |
                ╔═══════════════════╗                 |        |
                ║        Cloud      ║                 |        |
                ╚═══════╦═════╦═════╝                 |        |
      Macau     ╔═══════╩═════╩═════╗ `{:ok, 23.1°C}` |        |
───────────────>║  Weather actor #3 ╫─────────────────|───>    |
                ╚═══════════════════╝                 |    |   |
                ╔═══════════════════╗                 |    |   |
                ║        Cloud      ║                 |    |   |
                ╚═══════╦═════╦═════╝                 |    |   |
   Hong Kong    ╔═══════╩═════╩═════╗ `{:ok, 23.7°C}` |    |   |
───────────────>║  Weather actor #4 ╫─────────────>   |    |   |
                ╚═══════════════════╝              |  |    |   |
                ╔═══════════════════╗              |  |    |   |
                ║        Cloud      ║              |  |    |   |
                ╚═══════╦═════╦═════╝              |  |    |   |
      Kiev      ╔═══════╩═════╩═════╗ `{:ok, 3°C}` |  |    |   |
───────────────>║  Weather actor #5 ╫─────>        |  |    |   |
                ╚═══════════════════╝      |       |  |    |   |
                                           |       |  |    |   |
                                           |       |  |    |   |
───────────────────────────────────────────x───────x──x────x───x───────>
                                Time       5       4  2    3   1

The order of sent messages isn't guaranteed when processes don't
have to wait for each other.
```

You may wonder why you need the loop in the first place. In general, the
process should be able to handle more than one message. If you left out
the recursive call, then the moment the process handled that first (and
only) message, it would exit and be garbage-callected. You usually want
processes to be able to handle more than one message! Therefore, you
need a recursive call to the message-handling logic.

**Collecting and manipulating results with another actor**

Sending results to the shell session is great for seeing what messages
are sent by workers, but nothing more. If you want to manipulate the
results - say, by sorting them you need to find another way. Instead of
using the shell session as the sender, you can create another actor to
collect the results.

This actor must keep track of how many messages are expected. In order
words, the actor must keep state. How can you do that?

Let's set up the actor first. Create a file called `lib/coordinator.ex`,
and fill it as shown in the listing.

```elixir
defmodule OpenWeatherMap.Coordinator do
  def loop(results \\ [], results_expected) do
    receive do
      {:ok, result} ->
        new_results = [result|results]
        if results_expected == Enum.count(new_results) do
          send self, :exit
        end
        loop(new_results, results_expected)
      :exit ->
        IO.puts(results |> Enum.sort |> Enum.join(", "))
      _ ->
        loop(results, results_expected)
    end
  end
end
```

Let's see how you can use the coordinator together with the workers.
Open `lib/open_weather_map.ex`, and enter the code in the next listing.

```elixir
defmodule OpenWeatherMap do
  def temperatures_of(cities) do
    # Creates a coordinator process
    coordinator_pid = spawn(OpenWeatherMap.Coordinator, :loop, [[], Enum.count(cities)])

    # Iterates through each city
    cities |> Enum.each(fn city ->
      # Creates a worker process and executes its loop function
      worker_pid = spawn(OpenWeatherMap.Worker, :loop, [])
      # Sends the worker a message containing
      # the coordinator process's pid and city
      send worker_pid, {coordinator_pid, city}
    end)
  end
end
```

You can now determine the temperatures of cities by creating a list of
cities

```elixir
cities = ["Singapore", "Monaco", "Hong Kong", "Macau", "Kiev"]
```
and then calling `OpenWeatherMap.temperatures_of/1`

```elixir
OpenWeatherMap.temperatures_of(cities)
```

The result is as expected:

```elixir
Hong Kong: 22.5°C, Kiev: 2.3°C, Macau: 22.6°C, Monaco: 12.0°C, Singapore: 25.5°C
```

Here's how `OpenWeatherMap.temperatures_of/1` works. First you create a
coordinator process. The `loop` function of the coordinator process
expects two arguments: the current collected results and the total
expected number of results. Therefore, when you create the coordinator,
you initialize it with an empty result list and the number of cities:

```elixir
coordinator_pid = spawn(OpenWeatherMap.Coordinator, :loop, [[], Enum.count(cities)])
```

Now the coordinator process is waiting for messages from the worker.
Given a list of cities, you iterate through each city, create a worker,
and then send the worker a message containing the coordinator pid and
the city:

```elixir
cities |> Enum.each(fn city ->
  worker_pid = spawn(OpenWeatherMap.Worker, :loop, [])
  send worker_pid, {coordinator_pid, city}
```

Once all five workers have completed their requests, the coordinator
dutifully reports the results:

```elixir
Hong Kong: 22.5°C, Kiev: 2.3°C, Macau: 22.6°C, Monaco: 12.0°C, Singapore: 25.5°C
```

Success! Notice that the results are sorted in lexicographical order.

What kinds of messages can the coordinator receive from the worker?
Inspecting the `receive do ... end` block, you can conclude that there
are at least two kinds you're especially interested in:

* `{:ok, result}`
* `:exit`

Other kinds of messages are ignored. Let's examine each of message in
closer detail.

**`{:ok, result} - the happy path message`**

If nothing goes wrong, you expect to receive a "happy path" message from
a worker:

```elixir
def loop(results \\ [], results_expected) do
  receive do
    {:ok, result} ->
      new_results = [result|results] # adds result to current list of results
      # Checks if all results have been collected
      if results_expected == Enum.count(new_results) do
        # Sends the coordinator the exit message
        send self(), :exit
      end
      # Loops with new results. Notice that results_expected remains unchanged
      loop(new_results, results_expected)
      ...
  end
end
```

When the coordinator receives a message that fits the `{:ok, result}`
pattern, it adds the result to the current list of results (see figure).
Next, you check whether the coordinator has received the expected number
of results. Let's assume it hasn't. In this case, the `loop` function
calls itself again. Notice the arguments to the recursive call to `loop`
this time you pass in `new_results`, and `results_expected` remains
unchanged.

```bash
                ╔═══════════════════╗
                ║        Cloud      ║
                ╚═══════╦═════╦═════╝
    Singapore   ╔═══════╩═════╩═════╗ `{:ok, 27.4°C}` ╔═══════════════════╗
───────────────>║  Weather actor #1 ╫───────────────> ║ Coordinator actor ║
                ╚═══════════════════╝                 ╚═══════════════════╝
                                             Results: ["Singapore", 27.4°C]

    When the first result comes in, the actor saves the result in a list.
```

```bash
                ╔═══════════════════╗                ╔══════════════════╗
                ║        Cloud      ║                ║                  ║
                ╚═══════╦═════╦═════╝                ║                  ║
    Singapore   ╔═══════╩═════╩═════╗                ║                  ║
───────────────>║                   ║ `{:ok, 27.4°C}`║                  ║
                ║ Weather actor #1  ╫───────────────>║                  ║
                ║                   ║                ║                  ║
                ╚═══════════════════╝                ║                  ║
                ╔═══════════════════╗                ║                  ║
                ║        Cloud      ║                ║                  ║
                ╚═══════╦═════╦═════╝                ║                  ║
     Monaco     ╔═══════╩═════╩═════╗                ║                  ║
───────────────>║                   ║                ║                  ║
                ║ Weather actor #2  ╫───────────────>║                  ║
                ║                   ║                ║                  ║
                ╚═══════════════════╝                ║                  ║
                ╔═══════════════════╗                ║                  ║
                ║        Cloud      ║                ║                  ║
                ╚═══════╦═════╦═════╝                ║                  ║
   Hong Kong    ╔═══════╩═════╩═════╗                ║       Actor      ║
───────────────>║                   ║                ║                  ║
                ║ Weather actor #3  ╫───────────────>║                  ║
                ║                   ║                ║                  ║
                ╚═══════════════════╝                ║                  ║
                ╔═══════════════════╗                ║                  ║
                ║        Cloud      ║                ║                  ║
                ╚═══════╦═════╦═════╝                ║                  ║
     Macau      ╔═══════╩═════╩═════╗                ║                  ║
───────────────>║                   ║                ║                  ║
                ║ Weather actor #4  ╫───────────────>║                  ║
                ║                   ║                ║                  ║
                ╚═══════════════════╝                ║                  ║
                ╔═══════════════════╗                ║                  ║
                ║        Cloud      ║                ║                  ║
                ╚═══════╦═════╦═════╝                ║                  ║
      Kiev      ╔═══════╩═════╩═════╗                ║                  ║
───────────────>║                   ║  `{:ok, 3°C}`  ║                  ║
                ║ Weather actor #5  ╫───────────────>║                  ║
                ║                   ║                ║                  ║
                ╚═══════════════════╝                ╚══════════════════╝

                                                      Results: [
                                                        "Singapore: 27.4°C",
                                                        "Kiev: 3°C"
                                                      ]

When the coordinator receives the next message, it stores
it in the results list again. (continued on next page).
```

*`:exit` - the poison-pill message*

When the coordinator has received all the messages, it must find a way
to tell itself to stop and to report the results if necessary. A simple
way to do this is via a poison-pill message:

```elixir
def loop(results ]] [], results_expected) do
  receive do
    # ... other pattern omitted ...
    :exit ->
      # Prints the results lexicographically,
      # separated by commas
      IO.puts(results |> Enum.sort |> Enum.join(", "))
    # ... other pattern omitted
  end
end
```

```bash

                ╔══════════╗
                ║   Cloud  ║
                ╚══╦═════╦═╝
                   ║     ║
                   ║     ║                   ╔══════════════════╗
    Singapore   ╔══╩═════╩═╗                 ║                  ║
───────────────>║  Weather ║ `{:ok, 27.4°C}` ║                  ║
                ║ actor #1 ╫───────────────> ║                  ║
                ╚══════════╝                 ║                  ║
                ╔══════════╗                 ║                  ║
                ║   Cloud  ║                 ║                  ║
                ╚══╦═════╦═╝                 ║                  ║
                   ║     ║                   ║                  ║
                   ║     ║                   ║                  ║
     Monaco     ╔══╩═════╩═╗                 ║                  ║
───────────────>║  Weather ║ `{:ok, 12.0°C}` ║                  ║
                ║ actor #2 ╫───────────────> ║                  ║
                ╚══════════╝                 ║                  ║
                ╔══════════╗                 ║                  ║
                ║   Cloud  ║                 ║                  ║
                ╚══╦═════╦═╝                 ║                  ║
                   ║     ║                   ║   Coordinator    ║
                   ║     ║                   ║      actor       ║
     Macau      ╔══╩═════╩═╗                 ║                  ║
───────────────>║  Weather ║ `{:ok, 22.6°C}` ║                  ║
                ║ actor #3 ╫───────────────> ║                  ║
                ╚══════════╝                 ║                  ║
                                             ║                  ║
                ╔══════════╗                 ║                  ║
                ║   Cloud  ║                 ║                  ║
                ╚══╦═════╦═╝                 ║                  ║
                   ║     ║                   ║                  ║
                   ║     ║                   ║                  ║
   Hong Kong    ╔══╩═════╩═╗                 ║                  ║
───────────────>║  Weather ║ `{:ok, 22.5°C}` ║                  ║
                ║ actor #4 ╫───────────────> ║                  ║
                ╚══════════╝                 ║                  ║
                ╔══════════╗                 ║                  ║
                ║   Cloud  ║                 ║                  ║
                ╚══╦═════╦═╝                 ║                  ║
                   ║     ║                   ║                  ║
                   ║     ║                   ║                  ║
      Kiev      ╔══╩═════╩═╗                 ║                  ║
───────────────>║  Weather ║  `{:ok, 3°C}`   ║                  ║
                ║ actor #5 ╫───────────────> ║                  ║
                ╚══════════╝                 ║                  ║
                                             ╚══════════════════╝

                                              Results: [
                                                "Singapore: 27.4°C",
                                                "Monaco: 12.0°C",
                                                "Macau: 22.6°C",
                                                "Hong Kong: 22.5°C",
                                                "Kiev: 3°C"
                                              ]

When the coordinator receives the next  message, it stores it in
the results list again.
```

When the coordinator receives an `:exit` message, it prints out the
results lexicographically, separated by commas (see figure). Because
you want the coordinator to exit, you don't have to call the `loop`
function. Note that the `:exit` message isn't special; you can call
it `:kill`, `:self_destruct`, or `:kaboom`.

*other messages*

Finally, you must take care of any other types of messages the
coordinator may receive. You capture these unwanted messages with the
`_` operator. Remember to loop again, but leave the arguments
unmodified:

```elixir
def loop(results \\ [], results_expected) do
  receive do
    # ... other patterns omitted ...

    # Matches every other kind of message
    _ ->
      # Loops again, leaving the arguments unmodified
      loop(results, results_expected)
  end
end
```

```bash
                ╔══════════╗                    ╔═══════════╗
                ║   Cloud  ║                    ║ `{:exit}` ║
                ╚══╦═════╦═╝                    ╚═╦═══════╦═╝
                   ║     ║                        ║       ║
                   ║     ║                   ╔════╩═══════╩═════╗
    Singapore   ╔══╩═════╩═╗                 ║                  ║
───────────────>║  Weather ║ `{:ok, 27.4°C}` ║                  ║
                ║ actor #1 ╫───────────────> ║                  ║
                ╚══════════╝                 ║                  ║
                ╔══════════╗                 ║                  ║
                ║   Cloud  ║                 ║                  ║
                ╚══╦═════╦═╝                 ║                  ║
                   ║     ║                   ║                  ║
                   ║     ║                   ║                  ║
     Monaco     ╔══╩═════╩═╗                 ║                  ║
───────────────>║  Weather ║ `{:ok, 12.0°C}` ║                  ║
                ║ actor #2 ╫───────────────> ║                  ║
                ╚══════════╝                 ║                  ║
                ╔══════════╗                 ║                  ║
                ║   Cloud  ║                 ║                  ║
                ╚══╦═════╦═╝                 ║                  ║
                   ║     ║                   ║   Coordinator    ║
                   ║     ║                   ║      actor       ║
     Macau      ╔══╩═════╩═╗                 ║                  ║
───────────────>║  Weather ║ `{:ok, 22.6°C}` ║                  ║
                ║ actor #3 ╫───────────────> ║                  ║
                ╚══════════╝                 ║                  ║
                                             ║                  ║
                ╔══════════╗                 ║                  ║
                ║   Cloud  ║                 ║                  ║
                ╚══╦═════╦═╝                 ║                  ║
                   ║     ║                   ║                  ║
                   ║     ║                   ║                  ║
   Hong Kong    ╔══╩═════╩═╗                 ║                  ║
───────────────>║  Weather ║ `{:ok, 22.5°C}` ║                  ║
                ║ actor #4 ╫───────────────> ║                  ║
                ╚══════════╝                 ║                  ║
                ╔══════════╗                 ║                  ║
                ║   Cloud  ║                 ║                  ║
                ╚══╦═════╦═╝                 ║                  ║
                   ║     ║                   ║                  ║
                   ║     ║                   ║                  ║
      Kiev      ╔══╩═════╩═╗                 ║                  ║
───────────────>║  Weather ║  `{:ok, 3°C}`   ║                  ║
                ║ actor #5 ╫───────────────> ║                  ║
                ╚══════════╝                 ║                  ║
                                             ╚══════════════════╝

                                              Results: [
                                                "Singapore: 27.4°C",
                                                "Monaco: 12.0°C",
                                                "Macau: 22.6°C",
                                                "Hong Kong: 22.5°C",
                                                "Kiev: 3°C"
                                              ]

When the coordinator receives the `:exit` message, it returns the
results in alphabetical order and then exits.
```

Congratulations - you've just written you first concurrent program in
Elixir! You used multiple processes to perform computations concurrently.
The processes didn't have to wait for each other while perfoming
computations (except the coordinator process).

It's important to remember that there's no shared memory. The only way a
change of state can occur within a process is when a message is sent to
it. This is different from threads, because threads share memory. This
means multiple threads can modify the same memory - an endless source of
concurrency bugs (and headaches).

When designing your own concurrent programs, you must decide which types
of messages the processes should receive and send, along with the
interactions between processes. In the example  program, I decided to
see `{:ok, result}` and `:exit` for the coordinator process and
`{sender_pid, location}` for the worker process. I personally find it
helpful to sketch out the interactions between the various processes
along with the messages that are being sent and received. Resist the
temptation to dive right into coding, and spend a few minutes sketching.
Doing this will save you hours of head scratching and cursing!

**Exercise**

Processes are fundamental to Elixir. You'll gain a better understanding
only by running and experimenting with the code. Try these exercises:

1. Read the documentation for `send` and `receive`. For `send`, figure
   out the valid destinations to which you can send messages. For
   `receive`, study the example that the documentation provides.
2. Read the documentation for `Process`.
3. Write a programm that spawns two processes, You were introduced to
   the Actor concurrency model. Through the example application, you've
   learned how to do the following:

  * Create processes
  * Send and receive messages using processes
  * Achieve concurrency using multiple processes
  * Collect and manipulate messages from worker processes using a
    coordinator process

You've now had a taste of concurrent programming in Elixir! Be sure to
give your brain a little break. See you in the next section, where
you'll learn about Elixir's secret sauce: OTP!

### Nov 2017 Oleg G.Kapranov
