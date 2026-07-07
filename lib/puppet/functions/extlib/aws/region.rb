# frozen_string_literal: true

# @summary Returns the AWS region of the host running this function, read from its EC2 instance metadata (IMDS).
#
# This function is primarily intended to be used internally by other
# `extlib::aws` functions. It takes no parameters but depends on the EC2
# Instance metadata service (IMDS) being `enabled`, (ie on your EC2 based
# puppetserver or your agent if run as a `Deferred` function.)
Puppet::Functions.create_function(:'extlib::aws::region') do
  # The host's region is constant for the life of the process, so we only ever
  # query IMDS once and memoize the result process-wide.
  @cached_region = nil

  class << self
    attr_accessor :cached_region
  end

  # @return [String[1]] Returns an AWS region.
  dispatch :region do
    return_type 'String[1]'
  end

  def region
    self.class.cached_region ||= lookup_region
  end

  def lookup_region
    begin
      require 'aws-sdk-core'
    rescue LoadError => e
      raise Puppet::Error, "extlib::aws::region requires the 'aws-sdk-core' gem. (#{e.message})"
    end

    begin
      value = Aws::EC2Metadata.new.get('/latest/meta-data/placement/region')
    rescue StandardError => e
      raise Puppet::Error, "Unable to read AWS region from EC2 instance metadata: #{e.message}"
    end

    raise Puppet::Error, 'EC2 instance metadata returned an empty region.' if value.nil? || value.strip.empty?

    value.strip
  end
end
