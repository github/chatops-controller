# Chatops Controller

Rails helpers for easy and well-tested Chatops RPC. See the [protocol docs](docs/protocol-description.md)
for background information on Chatops RPC.

A minimal controller example:

```ruby
class ChatopsController < ApplicationController
  include ::Chatops::Controller

  # The default chatops RPC prefix. Clients may replace this.
  chatops_namespace :echo

  chatop :echo,
  /(?<text>.*)?/,
  "<text> - Echo some text back" do
    jsonrpc_success "Echoing back to you: #{jsonrpc_params[:text]}"
  end
end
```

Some routing boilerplate is required in `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  # Replace the controller: argument with your controller's name
  post "/_chatops/:chatop", controller: "chatops", action: :execute_chatop
  get  "/_chatops" => "chatops#list"
end
```

It's easy to test:

```ruby
class MyControllerTestCase < ActionController::TestCase
  include Chatops::Controller::TestCaseHelpers
  before do
    chatops_prefix "echo"
    chatops_auth!
  end

  def test_it_works
    chat "echo foo bar baz"
    assert_equal "foo bar baz", chatop_response
  end
end
```

Before you deploy, add the RPC authentication tokens to your app's environment,
below.

You're all done. Try `.echo foo`, and you should see your client respond with
`Echoing back to you: foo`.

A hubot client implementation is available at
<https://github.com/hubot-scripts/hubot-chatops-rpc>

## Usage

#### Namespaces

Every chatops controller has a namespace. All commands associated with this
controller will be displayed with `.<namespace>` in chat. The namespace is a
default chatops RPC prefix and may be overridden by a client.

```
chatops_namespace :foo
```

#### Creating Chatops

Creating a chatop is a DSL:

```ruby
chatop :echo,
/(?<text>.*)?/,
"<text> - Echo some text back" do
  jsonrpc_success "Echoing back to you: #{jsonrpc_params[:text]}"
end
```

In this example, we've created a chatop called `echo`. The next argument is a
regular expression with [named
captures](http://ruby-doc.org/core-1.9.3/Regexp.html#method-i-named_captures).
In this example, only one capture group is available, `text`.

The next line is a string, which is a single line of help that will be displayed
in chat for `.echo`.

The DSL takes a block, which is the code that will run when the chat robot sees
this regex. Arguments will be available in the `params` hash. `params[:user]`
and `params[:room_id]` are special, and will be set by the client. `user` will
always be the login of the user typing the command, and `room_id` will be where
it was typed.
The optional `mention_slug` parameter will provide the name to use to refer to
the user when sending a message; this may or may not be the same thing as the
username, depending on the chat system being used. The optional `message_id` parameter will provide a reference to the message that invoked the rpc.

You can return `jsonrpc_success` with a string to return text to chat. If you
have an input validation or other handle-able error, you can use
`jsonrpc_failure` to send a helpful error message.

Chatops are regular old rails controller actions, and you can use niceties like
`before_action` and friends. `before_action :echo, :load_user` for the above
case would call `load_user` before running `echo`.

## Authentication

Authentication uses the Chatops v3 public key signing protocol. You'll need
two environment variables to use this protocol:

`CHATOPS_AUTH_PUBLIC_KEY` is the public key of your chatops client in PEM
format. This environment variable will be the contents of a `.pub` file,
newlines and all.

`CHATOPS_AUTH_BASE_URL` is the base URL of your server as the chatops client
sees it. This is specified as an environment variable since rails will trust
client headers about a forwarded hostname. For example, if your chatops client
has added the url `https://example.com/_chatops`, you'd set this to
`https://example.com`.

You can also optionally set `CHATOPS_AUTH_ALT_PUBLIC_KEY` to a second public key
which will be accepted. This is helpful when rolling keys.

## Rails compatibility

This gem is intended to work with rails 6.x and 7.x. If you find a version
with a problem, please report it in an issue.

## Development

Changes are welcome. Getting started:

```
script/bootstrap
script/test
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution instructions.

## Upgrading from early versions

Early versions of RPC chatops had two major changes:

##### Using Rails' dynamic `:action` routing, which was deprecated in Rails 5.

To work around this, you need to update your router boilerplate:

This:

```ruby
  post  "/_chatops/:action", controller: "chatops"
```

Becomes this:

```ruby
  post  "/_chatops/:chatop", controller: "chatops" action: :execute_chatop
```

##### Adding a prefix

Version 2 of the Chatops RPC protocol assumes a unique prefix for each endpoint. This decision was made for several reasons:

 * The previous suffix-based system creates semantic ambiguities with keyword arguments
 * Prefixes allow big improvements to `.help`
 * Prefixes make regex-clobbering impossible

To upgrade to version 2, upgrade to version 2.x of this gem. To migrate:

 * Migrate your chatops to remove any prefixes you have:

```ruby
 chatop :foo, "help", /ci build whatever/, do "yay" end
```

Becomes:

```ruby
 chatop :foo, "help", /build whatever/, do "yay" end
```

 * Update your tests:

```ruby
  chat "ci build foobar"
```

Becomes:

```ruby
  chat "build foobar"
  # or
  chatops_prefix "ci"
  chat "ci build foobar"
```

##### Using public key authentication

Previous versions used a `CHATOPS_ALT_AUTH_TOKEN` as a shared secret. This form
of authentication was deprecated and the public key form used above is now
used instead.

### License

MIT. See the accompanying LICENSE file.
