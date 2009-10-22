%w(changes control creation reload reversion tagging version versions).each do |f|
  require File.join(File.dirname(__FILE__), 'vestal_versions', f)
end

module VestalVersions
  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def versioned(options = {})
      class_inheritable_accessor :version_only_columns
      self.version_only_columns = Array(options[:only]).map(&:to_s).uniq if options[:only]
      class_inheritable_accessor :version_except_columns
      self.version_except_columns = Array(options[:except]).map(&:to_s).uniq if options[:except]

      has_many :versions, :as => :versioned, :order => 'versions.number ASC', :dependent => :delete_all, :extend => Versions

      after_update :create_version, :if => :needs_version?

      include InstanceMethods
      include Changes
      include Reversion
      include Reload
    end
  end

  module InstanceMethods
    private
      def versioned_columns
        case
          when version_only_columns then self.class.column_names & version_only_columns
          when version_except_columns then self.class.column_names - version_except_columns
          else self.class.column_names
        end - %w(created_at created_on updated_at updated_on)
      end

      def needs_version?
        !(versioned_columns & changed).empty?
      end

      def create_version
        versions.create(:changes => changes.slice(*versioned_columns), :number => (last_version + 1))
        reset_version
      end
  end
end

ActiveRecord::Base.send(:include, VestalVersions)
