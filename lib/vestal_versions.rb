require 'version'

module LaserLemon
  module VestalVersions
    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def versioned
        has_many :versions, :as => :versioned, :order => 'versions.number ASC', :dependent => :destroy do
          def at(value)
            case value
              when Version; value
              when Numeric; find_by_number(value.floor)
              when Symbol; respond_to?(value) ? send(value) : nil
              when Date, Time; last(:conditions => ['versions.created_at <= ?', value.to_time])
            end
          end

          def between(from_value, to_value)
            from, to = number_at(from_value), number_at(to_value)
            return [] if from.nil? || to.nil? || (from == to)
            all(
              :conditions => {:number => Range.new(*[from, to].sort)},
              :order => "versions.number #{(from > to) ? 'DESC' : 'ASC'}"
            )
          end

          private

            def number_at(value)
              case value
                when Version; value.number
                when Numeric; value.floor
                when Symbol, Date, Time; at(value).try(:number)
              end
            end
        end

        after_save :create_version, :if => :needs_version?

        include InstanceMethods
      end
    end

    module InstanceMethods
      private

        def needs_version?
          !changed.empty?
        end

        def reset_version(new_version = nil)
          @version = new_version
        end

        def create_version
          if versions.empty?
            versions.create(:changes => attributes, :number => 1)
          else
            reset_version
            versions.create(:changes => changes, :number => (version.to_i + 1))
          end

          reset_version
        end

      public

        def version
          @version ||= versions.maximum(:number)
        end

        def revert_to(value)
          chain = versions.between(version, value)
          return version unless chain.size > 1

          new_version = chain.last.number
          backward = chain.first > chain.last
          backward ? chain.pop : chain.shift

          timestamps = %w(created_at created_on updated_at updated_on)

          chain.each do |version|
            version.changes.except(*timestamps).each do |attribute, change|
              new_value = backward ? change.first : change.last
              write_attribute(attribute, new_value)
            end
          end

          reset_version(new_version)
        end

        def revert_to!(value)
          revert_to(value)
          reset_version if saved = save
          saved
        end

        def last_changes
          return {} if version == 1
          versions.at(version).changes
        end

        def last_changed
          last_changes.keys
        end
    end
  end
end

ActiveRecord::Base.send(:include, LaserLemon::VestalVersions)
