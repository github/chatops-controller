# Why Chatops RPC?

Chatops RPC is distilled from several years' experience working with Chatops
at GitHub. The protocol is simple and will not cover every use case, but
internal adoption has been excellent.

### What came first

#### Hubot

Our first generation of chatops were written directly as Hubot scripts. These
work fine for situations where there's an existing API that's well-supported.
But if the API wasn't designed to do what the chat command wanted, a single
command might end up making several REST API calls, with all the associated
error handling, responses, etc. REST API endpoints created explicitly for chat
commands tended to be challenging to test end-to-end, since lots of the
logic would end up wrapped in hubot and outputting chat-adapter-specific things.

#### Shell

Next we wrote a bridge from a pile of shell scripts to hubot. This had great
adoption, but it had its own problems. Security contexts were often mixed up
with each other, so there were very poor boundaries between what access tokens
a script needed and had available. Several different services made more
sense being written as shell, ruby, python, go, and more, and this mishmash
meant that in practice very little code was reused or tested.

#### The pattern

Over time, we settled on a new pattern: direct hubot bindings to API endpoints
written just for hubot. This resulted in a few services with a few hundred
lines of boilerplate node, wrapping API calls.

This pattern was a winner, though. Servers were able to test their commands
end-to-end, missing out only on the regular expressions that might trigger a
command. Responses and changes to state could be tested in one place.

Chatops RPC is a distillation and protocol around the last pattern of RPC
endpoints with a one-to-one mapping to a chat command.

### Authentication

Chatops RPC servers need to trust the username that the chat bridge gives them.
This means that a shared token gives servers the ability to misrepresent users
with other servers. In this case, there's a lot of trust built in to the chat
bridge, and we find this maps well to the asymmetric crypto authentication.

### Keyword Arguments

We pair this system with <https://github.com/bhuga/hubot-chatops-rpc>, which
provides generic argument support for long arguments, like `--argument foo`.
While regexes create much more natural commands, rarely used options tend to
create ugly regexes that are hard to test. If a command can potentially take 10
arguments, it's almost certain the regex will have unhandled edge cases. Generic
arguments provide an easy way to take rarely-used options. These are not part
of the Chatops RPC protocol but it's highly recommended to use a client that
supports them.

Keyword arguments are also important for searching chat history. In the past, we
had several commands that had strange regex forms for different operations. It's
hard to find examples to use these unusual forms. For example, `.deploy!` has
become `.deploy --force`, which is much clearer for new employees and easier to
find examples of.

### Testing

Highly testable patterns were a core consideration of Chatops RPC. GitHub had
grown quite dependent on Chatops as a core part of its workflow, but a very
large number of them were not tested. We've had several instances of important
but rarely-used chat operations failing during availability incidents. Chatops
RPC brings the entire flow to the server, and this results in highly testable
operations that will work when they need to.

### Prefixes

Prefixes provide a way for more than one of the same endpoint to coexist. Over
the years, we've had several systems with staging environments or other
contexts. Ad-hoc solutions, unique to each, were created, forcing developers to
learn new ways to manage the context of multiple chat-connected systems.

Prefixes provide a way to have two systems, such as `.deploy` and
`.deploy-staging` for a staging deployments system. Prefixes also provide a way
to interface with endpoints that are associated with a resource they manage. For
example, if your site has multiple kubernetes clusters, perhaps a server to
manage each would be stood up, one per cluster, each including the cluster
name in the prefix. This allows you to write "manage kubernetes cluster" once
but have `.kubectl@cluster1 list pods` and `.kubectl@cluster2 list pods`.

Internally, we use Hubot middleware to alias some very commonly used commands
to shorter versions that do not use the same prefix.
