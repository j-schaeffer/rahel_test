# Indexable
# 2014-10-17 lukas.rosentreter@gmail.com
require Rails.root.join("config", "elasticsearch")

module Rahel
  module Indexable
    module ClassMethods
      # Accessor für provide_indexdata
      def indexmapping
        @indexmapping
      end

      def category name
        set_indexmapping :category, name
      end

      def headline *args
        add_indexmapping :headline, args
      end

      def subheadline *args
        add_indexmapping :subheadline, args
      end

      def description *args
        add_indexmapping :description, args
      end

      def facet name, *args
        @indexmapping ||= {}
        @indexmapping[:facet] ||= {}
        @indexmapping[:facet][name] ||= []
        @indexmapping[:facet][name] << args
      end

      def separator searchfield, sep
        @indexmapping ||= {}
        @indexmapping[:separator] ||= {}
        @indexmapping[:separator][searchfield] = sep
      end

      private

      def set_indexmapping searchfield, args
        @indexmapping ||= {}
        @indexmapping[searchfield] = args
      end

      def add_indexmapping searchfield, args
        @indexmapping ||= {}
        @indexmapping[searchfield] ||= []
        @indexmapping[searchfield] << args
      end

    end

    module InstanceMethods
      def provide_indexdata
        # Standard Indexdaten, die jedes Individual hat
        indexdata = {
          id: id,
          klass: self.class.name,
          #scope: User::ROLES.drop(User::ROLES.index(visibility)), # Array of roles >= visibility
          scope: visibility,
          related_ids: [id],
          label: label,
          inline_label: inline_label,
          thumb: thumb ? thumb.to_i : 0
        }

        # Gibt es ein Mapping für weitere Suchdaten?
        if self.class.indexmapping ||
            self.class.ancestors.select { |a| a < Individual && a.indexmapping}.any?
          mp = self.class.indexmapping || {}

          # Indexmappings von Superklassen übernehmen
          self.class.ancestors
            .select { |a| a < Individual && a.indexmapping}
            .map(&:indexmapping)
            .each do |am|
              mp = am.deep_merge(mp) do |k,v1,v2|
                if v1.is_a?(Array) && v2.is_a?(Array)
                  # Merge if both are Arrays
                  (v1 + v2).compact.uniq
                else
                  # Don't overwrite with nil
                  v2.nil? ? v1 : v2
                end
              end
          end

          # Suchkategorie hinzufügen, falls gegeben
          indexdata[:category] = mp[:category] if mp[:category]

          ids = [id]

          # Volltext-Suchfelder abfragen
          %i(headline subheadline description).each do |searchfield|
            next unless mp[searchfield]
            data = []
            mp[searchfield].each do |path|
              rids, rdata = resolve_index_values(path)
              ids += rids
              data += rdata
            end

            sep = mp[:separator] && mp[:separator][searchfield] ? mp[:separator][searchfield] : ", "
            indexdata[searchfield] = data.compact.uniq.join(sep)
          end

          # Facetten-Felder abfragen
          if mp[:facet]
            indexdata[:facet] = {}

            # TODO: Alle keys durchgehen
            mp[:facet].keys.each do |facet|
            #ESConfig.facets.keys.each do |facet|
              data = []
              mp[:facet][facet].each do |path|
                rids, rdata = resolve_index_values(path, value_callback: :facet_value)
                ids += rids
                data += rdata
              end if mp[:facet][facet]
              indexdata[:facet][facet] = data.compact.uniq
            end
          end

          # Related IDs einpflegen
          indexdata[:related_ids] = ids.compact.uniq
        end

        return indexdata
      end

      private

      def resolve_index_values path, recievers=[self], value_callback: :index_value
        if path.first.is_a? String
          return recievers.map(&:id), [path.first]
        end

        if path.first == :self
          return recievers.map(&:id), recievers.map(&value_callback).map(&:strip)
        end

        if path.first == :label
          return recievers.map(&:id), recievers.map(&:label).map(&:strip)
        end

        if path.first == :inline_label
          return recievers.map(&:id), recievers.map(&:inline_label).map(&:strip)
        end

        # if not self or label, path.first should be a property
        # also all recievers should be of the same type
        prop = recievers.first.predicates[path.first.to_s]

        raise "Incorrect argument: Property not found!" if prop.nil?

        # accumulate all properties related to given recievers
        if prop[:cardinality] == 1
          props = recievers.map(&path.first)
        else
          props = []
          recievers.each do |r|
            props += r.send(path.first)
          end
        end
        props.compact!

        # found properties?
        return recievers.map(&:id), [] unless props.size > 0

        if prop[:type] == :objekt
          #properties point to individuals
          ivs = props.map(&:value)

          if path.size > 1
            # chain more properties, if path still contains more
            ids, values = resolve_index_values(path.drop(1), ivs, value_callback: value_callback)
            return recievers.map(&:id) + ids, values
          else
            # get indexvalues of individuals
            return recievers.map(&:id) + ivs.map(&:id), ivs.map(&value_callback).map(&:strip)
          end
        else
          # data properties
          return recievers.map(&:id), props.map(&:index_value).map(&:strip)
        end
      end
    end
  end
end