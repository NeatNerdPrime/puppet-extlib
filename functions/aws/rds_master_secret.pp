# @summary Convenience wrapper function for retrieving the AWS managed master secret of an RDS database instance.
#
# @param db_instance_identifier
#   The RDS instance identifier or ARN
# @param region
#   Optionally specify your AWS region. If not given, the `extlib::aws::region` function will be used to fetch the region.
# @return The DB instance master secret hash, containing details such as the `username` and `password` depending on RDS instance type.
function extlib::aws::rds_master_secret (
  String[1] $db_instance_identifier,
  Optional[String[1]] $region = undef,
) >> Hash {
  $rds_db_instance = extlib::aws::rds::db_instances($db_instance_identifier, $region)
  $rds_master_user_secret = $rds_db_instance['master_user_secret']

  unless $rds_master_user_secret =~ Hash {
    fail("RDS DB instance '${db_instance_identifier}' has no AWS managed master secret (master_user_secret).")
  }

  unless $rds_master_user_secret['secret_status'] == 'active' { fail('rds_master_user_secret was not in state `active`') }

  extlib::aws::secretsmanager::secret_value($rds_master_user_secret['secret_arn'], $region)
}
