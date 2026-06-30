# frozen_string_literal: true

# @summary Wraps Amazon RDS DescribeDBInstances to return detailed information on one or all RDS database instances.
#
# This function queries the Amazon RDS API to retrieve information on RDS
# database instances.
#
# Currently, it only supports querying the instances using the IAM role
# permissions of the EC2 instance running the function, (usually your
# puppetserver unless the function call is `Deferred`), and it only supports
# querying the instances in the same account as it is being run.
Puppet::Functions.create_function(:'extlib::aws::rds::db_instances') do
  # @param db_instance_identifier The RDS instance identifier or ARN of the DB instance. If omitted, returns an Array containing details of _all_ instances.
  # @param region The AWS region as used when creating the API client. If omitted (or explicitly passed `undef`), the region will be automatically looked up from the metadata of the EC2 instance running the function.
  # @return [Variant[Array[Hash],Hash]] Returns a hash containing the DB instance data, or an Array of such hashes if the `db_instance_identifier` parameter was not specified.
  dispatch :db_instances do
    optional_param 'String[1]', :db_instance_identifier
    optional_param 'Variant[Undef, String[1]]', :region
    return_type 'Variant[Array[Hash],Hash]'
  end

  require 'json'

  def db_instances(db_instance_identifier = nil, region = nil)
    begin
      require 'aws-sdk-rds'
    rescue LoadError => e
      raise Puppet::Error, "extlib::aws::rds::db_instances requires the 'aws-sdk-rds' gem. (#{e.message})"
    end

    region ||= call_function('extlib::aws::region')
    client = Aws::RDS::Client.new(region: region)

    begin
      resp = client.describe_db_instances(db_instance_identifier: db_instance_identifier)
      instances = resp.each_page.flat_map(&:db_instances)
    rescue Aws::RDS::Errors::DBInstanceNotFound => e
      raise Puppet::Error, "RDS DB instance '#{db_instance_identifier}' not found: #{e.message}"
    rescue Aws::Errors::ServiceError => e
      raise Puppet::Error, "Error describing RDS DB instance(s): #{e.message}"
    end

    if db_instance_identifier
      # We should have *exactly* one db instance returned, so this is a sanity check.
      raise Puppet::DevError, "RDS DB instance '#{db_instance_identifier}' not found?!" if instances.size != 1

      # JSON.parse(JSON.dump(x)) is a convenient way to recursively convert all symbols into normal strings.
      JSON.parse(JSON.dump(instances.first.to_h))
    else
      instances.map do |instance|
        JSON.parse(JSON.dump(instance.to_h))
      end
    end
  end
end
