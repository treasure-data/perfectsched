$LOAD_PATH.unshift(File.expand_path('../lib', File.dirname(__FILE__)))

require 'perfectsched'

if ENV['SIMPLE_COV']
  require 'simplecov'
  SimpleCov.start do
    add_filter 'spec/'
    add_filter 'pkg/'
    add_filter 'vendor/'
  end
end

if ENV['CI']
  require 'coveralls'
  Coveralls.wear!
end

require 'fileutils'

def test_sched_config
  {:type=>'rdb_compat', :url=>'sqlite://spec/test.db', :table=>'test_scheds'}
end

def create_test_sched
  FileUtils.rm_f 'spec/test.db'
  sc = PerfectSched.open(test_sched_config)

  sql = %[
    CREATE TABLE IF NOT EXISTS `test_scheds` (
      id VARCHAR(256) NOT NULL,
      timeout INT NOT NULL,
      next_time INT NOT NULL,
      cron VARCHAR(128) NOT NULL,
      delay INT NOT NULL,
      data BLOB NOT NULL,
      timezone VARCHAR(256) NULL,
      PRIMARY KEY (id)
    );]

  sc.client.backend.db.run sql

  return sc
end

def get_test_sched
  PerfectSched.open(test_sched_config)
end

include PerfectSched

