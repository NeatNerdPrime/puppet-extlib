# frozen_string_literal: true

# @summary Retrieves and parses an AWS Secrets Manager secret
#
# This function queries the Amazon SecretsManager API to retrieve a secret
# based on the ARN provided.
#
# Currently, it only supports querying the instances using the IAM role
# permissions of the EC2 instance running the function, (usually your
# puppetserver unless the function call is `Deferred`), and it only supports
# fetching secrets from the same account as the function is being run.
Puppet::Functions.create_function(:'extlib::aws::secretsmanager::secret_value') do
  # @param secret_arn The ARN of the secret to fetch.
  # @param region The AWS region as used when creating the API client. If omitted (or explicitly passed `undef`), the region will be automatically looked up from the metadata of the EC2 instance running the function.
  # @return [Variant[Sensitive[String[1]], Hash, Sensitive[Hash]]] Returns the secret. For plain text secrets, the function will return a `Sensitive[String]`. For key:value secrets, the secret JSON will be decoded. If the secret contains a `password` field, this will be returned as a `Sensitive[String]` within the `Hash` returned. If there isn't a `password` field, the complete hash will be returned wrapped in `Sensitive`.
  dispatch :secret_value do
    param 'String[1]', :secret_arn
    optional_param 'Variant[Undef, String[1]]', :region
    return_type 'Variant[Sensitive[String[1]], Hash, Sensitive[Hash]]'
  end

  require 'json'

  def secret_value(secret_arn, region = nil)
    begin
      require 'aws-sdk-secretsmanager'
    rescue LoadError => e
      raise Puppet::Error, "extlib::aws::secretsmanager::secret_value requires the 'aws-sdk-secretsmanager' gem. (#{e.message})"
    end

    region ||= call_function('extlib::aws::region')
    client = Aws::SecretsManager::Client.new(region: region)

    begin
      resp = client.get_secret_value(secret_id: secret_arn)
    rescue Aws::SecretsManager::Errors::ResourceNotFoundException => e
      raise Puppet::Error, "Secret '#{secret_arn}' not found: #{e.message}"
    rescue Aws::Errors::ServiceError => e
      raise Puppet::Error, "Error retrieving secret '#{secret_arn}': #{e.message}"
    end

    payload = resp.secret_string
    raise Puppet::Error, "Secret '#{secret_arn}' has no SecretString (binary secrets are not supported)" if payload.nil?

    begin
      data = JSON.parse(payload)
    rescue JSON::ParserError
      data = nil
    end

    # Anything that isn't a JSON object (a plain string, or a JSON scalar such
    # as a number or boolean) is treated as a 'normal' string secret which we
    # wrap in Sensitive and return.
    return Puppet::Pops::Types::PSensitiveType::Sensitive.new(payload) unless data.is_a?(Hash)

    # Either wrap a `password` field if it exists, or the whole Hash otherwise
    if data.key?('password')
      data['password'] = Puppet::Pops::Types::PSensitiveType::Sensitive.new(data['password'])
    else
      data = Puppet::Pops::Types::PSensitiveType::Sensitive.new(data)
    end

    data
  end
end
