# ChatopsControllers

Rails helpers for easy, JSON-RPC based chatops.

A minimal controller example:

```ruby
class ChatOpsController < ApplicationController
  include ::ChatOps::Controller

  chatops_namespace :echo

  chatop :echo,
  /echo (?<text>.*)?/,
  "echo <text> - Echo some text back" do
    jsonrpc_success "Echoing back to you: #{jsonrpc_params[:text]}"
  end
end
```

Some routing boilerplate is required in `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  post "/_chatops/:chatop", controller: "anonymous", action: :execute_chatop
  get  "/_chatops" => "chatops#list"
end
```

Before you deploy, add the RPC authentication tokens to your app's environment,
below.

Next, tell hubot about your endpoint:

```
.rpc add https://myapp.githubapp.com/_chatops
```

You're all done. Try `.echo foo`, and you should see Hubot respond with `Echoing back to you: foo`.

## Usage

#### Namespaces

Every chatops controller has a namespace. All commands associated with this
controller will be displayed with `.help <namespace>`. Commands will also be
dispalyed with subsets of their text.

```
chatops_namespace :foo
```
#### Creating Chatops

Creating a chatop is a DSL:

```ruby
chatop :echo,
/echo (?<text>.*)?/,
"echo <text> - Echo some text back" do
  jsonrpc_success "Echoing back to you: #{jsonrpc_params[:text]}"
end
```

In this example, we've created a chatop called `echo`. The next argument is a
regular expression with [named
captures](http://ruby-doc.org/core-1.9.3/Regexp.html#method-i-named_captures).
In this example, only one capture group is available, `text`.

The next line is a string, which is a single line of help that will be displayed
in chat for `.help echo`.

The DSL takes a block, which is the code that will run when the chat robot sees
this regex. Arguments will be available in the `params` hash. `params[:user]`
and `params[:room_id]` are special, and will be set by hubot. `user` will always
be the github login of the user typing the command, and `room_id` will be where
it was typed.

You can return `jsonrpc_success` with a string to return text to chat. If you
have an input validation or other handle-able error, you can use
`jsonrpc_failure` to send a helpful error message.

ChatOps are regular old rails controller actions, and you can use niceties like
`before_action` and friends. `before_action :echo, :load_user` for the above
case would call `load_user` before running `echo`.

## Authentication

Add the tokens to your app's environment:

```shell
$ gh-config CHATOPS_AUTH_TOKEN=abc CHATOPS_ALT_AUTH_TOKEN=abc myapp
```

## Staging

Use `.rpc set suffix https://myapp.githubapp.com/_chatops in staging`, and all
your chatops will require the suffix `in staging`. This means you can do `.echo
foo` and `.echo foo in staging` to use two different servers to run `.echo foo`.

## Development

```
script/bootstrap
script/test
```

## Upgrading from early versions

Early versions of RPC chatops had two major changes:

##### They used Rails' dynamic `:action` routing, which was depcrated in Rails 5.

To work around this, you need to update your router boilerplate:

This:

```ruby
  post  "/_chatops/:action", controller: "anonymous"
```

Becomes this:

```ruby
  post  "/_chatops/:chatop", controller: "anonymous", action: :execute_chatop
```

#####

They did not require a prefix. Version 2 of the Chatops RPC protocol assumes a unique prefix for each endpoint. This decision was made for several reasons:

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
```

 * Remove and re-add your endpoint with a prefix:

```
.rpc delete https://my-endpoint.dev
.rpc add https://my-endpoint.dev with prefix ci
```
