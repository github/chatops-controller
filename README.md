# ChatopsControllers

Rails helpers for JSON-RPC based easy chatops.

A minimal controller example:

```ruby
class ChatOpsController < ApplicationController
  include ::ChatOps::ControllerHelpers

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
  post "/_chatops/:action", controller: "anonymous"
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

You can return `jsonrpc_success` with a string to return text to chat. It's fine
to post error conditions, like `project not found`, using `jsonrpc_success`.
In this case, `jsonrpc_success` implies that the RPC worked, not the command.

ChatOps are regular old rails controller actions, and you can use niceties like
`before_filter` and friends. `before_filter :echo, :load_user` for the above
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
