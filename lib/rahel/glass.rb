# 2014-06-17 marius.gawrisch@gmail.com

module Rahel
  class Glass
    def initialize controller
      @controller = controller
    end

    def humanize individual, predicate
      # Bei SAD gab es häufig den Fall, dass ein und dasselbe Prädikat bei verschiedenen
      # Individuals verschieden übersetzt wurde. Deshalb waren die Prädikate in de.yml
      # nach den Individual-Klassen sortiert. Daher sah die Funktion so aus:
      #
      # I18n.translate "#{individual.class.name}.#{predicate}"
      #
      # Bei Maya ist das (bisher) nicht der Fall, deswegen können wir hier die Prädikate
      # auf der ersten Ebene haben:
      I18n.translate predicate
    end

    #
    # INLINE
    #

    def inline individual, predicate, locals: {}
      editable = @controller.current_user.can_edit_property?(predicate, individual)
      @controller.render_to_string(
        partial: "glass/inline/property_group",
        locals: {
          individual: individual,
          predicate: predicate,
          editable: editable,
        }.merge(locals)
      ).html_safe
    end

    def inline_individual individual, locals: {}
      template = "glass/inline/#{individual.class.name.underscore}"
      if @controller.template_exists?(template, [], true)
        @controller.render_to_string(
          partial: template,
          locals: { individual: individual }.merge(locals)
        ).html_safe
      else
        individual.to_s
      end
    end

    def inline_property property, locals: {}
      @controller.render_to_string(
        partial: "glass/inline/property",
        locals: { property: property }.merge(locals)
      ).html_safe
    end

    #
    # EDIT
    #

    def edit individual, predicate, locals: {}
      # Spezialfall für das Label von Personen.
      if predicate == "label" && individual.computed_label?
        return edit_individual individual, label: true, locals: locals
      end

      props = individual.sorted_editable_properties(predicate, @controller.current_user)
      prop_class = individual.class_of(predicate)

      if props.any?
        props.map { |prop| edit_property(prop, locals: locals) }.join.html_safe
      elsif individual.cardinality_of(predicate) == 1
        # Wir müssen vielleicht etwas anzeigen, obwohl kein Property in der DB ist.

        if prop_class == PropertyObjekt && individual.editable?(predicate)
          # Es handelt sich um ein "weak"-Individual-Fall.
          # (Dieser Fall tritt in Maya nicht auf, da es keine weak Individuals gibt, die an
          # einem cardinality-1-Property hängen.)

          # Zuerst das Individual erstellen (mit Revision)
          objekt = Individual.create(type: individual.singular_range_of(predicate))
          Revision.create_from_new_individual(objekt, @controller.current_user)

          # Nun die Property dazwischen (wieder mit Revision). (Inverse werden ggf. erstellt.)
          prop = individual.send("#{predicate}=", objekt)
          Revision.create_from_new_property(prop, @controller.current_user)
          Revision.create_from_new_property(prop.inverse, @controller.current_user) if prop.inverse
          edit_property prop
        elsif prop_class != PropertyObjekt
          # Es ist nicht Objekt, es reicht daher ein fake Property.
          prop = prop_class.new(subject: individual,
                                predicate: predicate)
          edit_property(prop, locals: locals)
        end
      end
    end

    def edit_property property, locals: {}
      @controller.render_to_string(
        partial: "glass/edit/property",
        locals: { property: property }.merge(locals)
      ).html_safe
    end

    # subject ist dafür da, bei Curatorships zu entscheiden, ob man sie aus der Personen-Sicht
    # oder aus der Sammlungs-Sicht sieht.
    def edit_individual individual, label: false, subject: nil, locals: {}
      template = "glass/edit/#{individual.class.name.underscore}"
      template += "_label" if label
      if @controller.template_exists?(template, [], true)
        @controller.render_to_string(
          partial: template,
          locals: { individual: individual, subject: subject }.merge(locals)
        ).html_safe
      else
        ("<em>Bitte das Template glass/edit/_#{template}.html.erb erstellen!</em>").html_safe
      end
    end

    #
    # NEW
    #

    def new individual, predicate
      @controller.render_to_string(
        partial: "glass/new/property",
        locals: { predicate: predicate, individual: individual }
      ).html_safe
    end
  end
end
