module Chatops
  # THREAD_STYLES defines the various thread styles available to Hubot Chatops RPC.
  # https://github.com/github/hubot-classic/blob/master/docs/rpc_chatops_protocol.md#executing-commands
  THREAD_STYLES = {
    # Channel thread style is a standard in-channel reply.
    channel: 0,
    # Threaded thread style will send the reply to a thread from the original message.
    threaded: 1,
    # Threaded and channel thread style will send the reply to a thread from the original message,
    # and post an update into the channel as well (helpful when the original message in the thread is old).
    threaded_and_channel: 2,
  }.freeze

  def self.public_key
    ENV[public_key_env_var_name]
  end

  def self.public_key_env_var_name
    "CHATOPS_AUTH_PUBLIC_KEY"
  end

  def self.alt_public_key
    ENV["CHATOPS_AUTH_ALT_PUBLIC_KEY"]
  end

  def self.auth_base_url
    ENV[auth_base_url_env_var_name]
  end

  def self.auth_base_url_env_var_name
    "CHATOPS_AUTH_BASE_URL"
  end
end
