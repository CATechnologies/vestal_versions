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
      alias_method_chain :reload, :versions
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

      def reset_version(new_version = nil)
        @last_version = nil if new_version.nil?
        @version = new_version
      end

      def create_version
        versions.create(:changes => changes.slice(*versioned_columns), :number => (last_version + 1))
        reset_version
      end

    public
      def version
        @version ||= last_version
      end

      def last_version
        @last_version ||= versions.maximum(:number) || 1
      end

      def reverted?
        version != last_version
      end

      def reload_with_versions(*args)
        reset_version
        reload_without_versions(*args)
      end

      def changes_between(from, to)
        from_number, to_number = versions.number_at(from), versions.number_at(to)
        return {} if from_number == to_number
        chain = versions.between(from_number, to_number)
        return {} if chain.empty?

        backward = from_number > to_number
        backward ? chain.pop : chain.shift unless [from_number, to_number].include?(1)

        chain.inject({}) do |changes, version|
          version.changes.each do |attribute, change|
            change.reverse! if backward
            new_change = [changes.fetch(attribute, change).first, change.last]
            changes.update(attribute => new_change)
          end
          changes
        end
      end

      def revert_to(value)
        to_number = versions.number_at(value)
        changes = changes_between(version, to_number)
        return version if changes.empty?

        changes.each do |attribute, change|
          write_attribute(attribute, change.last)
        end

        reset_version(to_number)
      end

      def revert_to!(value)
        revert_to(value)
        reset_version if saved = save
        saved
      end

      def latest_changes
        return {} if version.nil? || version == 1
        versions.at(version).changes
      end
  end
end

ActiveRecord::Base.send(:include, VestalVersions)
