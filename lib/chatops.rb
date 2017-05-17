module ChatOps
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
