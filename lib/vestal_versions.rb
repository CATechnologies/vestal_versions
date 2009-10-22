%w(changes control creation reload reversion tagging version versions).each do |f|
  require File.join(File.dirname(__FILE__), 'vestal_versions', f)
end

module VestalVersions
  def versioned(options = {})
    class << self
      def versioned?
        true
      end
    end

    class_inheritable_accessor :version_only_columns
    self.version_only_columns = Array(options[:only]).map(&:to_s).uniq if options[:only]
    class_inheritable_accessor :version_except_columns
    self.version_except_columns = Array(options[:except]).map(&:to_s).uniq if options[:except]

    has_many :versions, :class_name => '::VestalVersions::Version', :as => :versioned, :order => 'versions.number ASC', :dependent => :delete_all, :extend => Versions

    include Changes
    include Creation
    include Reversion
    include Reload
  end

  def versioned?
    false
  end
end

ActiveRecord::Base.extend(VestalVersions)
