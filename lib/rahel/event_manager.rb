# 2014-12-22 marius.gawrisch@mgaw.de

# type is a string, f.ex. type == "Person"
# klass is a class, f.ex. klass == Person

# Abkürzungen:
# indi: individual
# rev: revision
# prop: property
# val: value

# "revision_id" wird übergeben, um folgendes Feature zu ermöglichen: Der Benutzer ändert
# den Wert eines Text-Propertys, und die Änderung wird auto-gespeichert, weil der Benutzer
# sehr langsam tippt, oder kurz überlegen muss. Der Benutzer ist aber noch nicht fertig,
# ändert weitere Buchstaben, und es wird wieder, diesmal endgültig, auto-gespeichert.
# In einem solchen Fall soll nur *eine* Revision existieren. Deshalb wird die Revisions-Id
# herumgereicht, damit man die beim ersten Speichern erstellte Revision im Nachhinein
# noch aktualisieren kann.

# Revisionen, die als "hide_on_global_list" markiert sind, werden *nicht* auf der globalen
# Revisionsliste angezeigt, sondern *nur* auf der lokalen Revisionsliste eines Individuals.
#
# Eine Revision kann aus verschiedenen Gründen so markiert werden:
#
# - Die Revision ist in einer Löschkaskade entstanden. Wenn ein Individual gelöscht wird,
#   dann kümmert sich dieser EventManager darum, dass vorher alle Properties gelöscht
#   werden, die da dran hängen. Dann wird jedesmal eine Revision erstellt, aber die sollen
#   natürlich nicht alle auf der globalen Revisionsliste erscheinen.
#
# - Ein Individual mit zusammengesetztem Label wird erstellt (zum Beispiel Person). Dann
#   werden für Name, Vorname usw. jeweils eigenen Revisionen erstellt, die aber nicht auf
#   der globalen Liste erscheinen sollen.
#
# - Bei Individual-Erstellung wird ein Property erstellt, dass die Sichtbarkeit des
#   Individuals regelt. Auch diese Erstellung soll nur lokal sichtbar sein.
#
# - Wenn ein Member ein Individual erstellt, dann wird ein "can_edit" Property erstellt,
#   damit er oder sie dieses Individual dann später auch bearbeiten darf. Auch nur lokal
#   sichtbar.

# "check_permissions" wird auf false gesetzt, wenn:
#
# - Wenn ein Member einen Individual erstellt, dann werden auch Propertys erstellt, die der
#   Member eigentlich nicht erstellen bzw. bearbeiten darf: "member.can_edit = new_indi" und
#   "new_indi.visible_for = :member". Deshalb wird hier die Rechteabfrage deaktiviert.
#
# - Wenn jemand einen Individual löscht, dann kann es im Prinzip passieren, dass die Person
#   zwar den Individual löschen darf, aber nicht jedes seiner Propertys bearbeiten darf
#   (zB "visible_for"). Das tritt bei Maya zur Zeit nicht auf, da nur Manager das Rechte haben,
#   Individuals zu löschen, und die können auch alle Propertys bearbeiten. Aber es ist möglich,
#   Rahel anders zu konfigurieren, und das sollte im EventManager berücksichtigt werden.
#
# - Wenn ein Member für eine seiner Sammlungen ein Curatorship erstellt, dann muss auch dem
#   Curatorship eine Person (predicate: "curator") zugewiesen werden. Das dürfen aber eigentlich
#   nur Manager, da sonst die Gefahr bestünde, dass ein Member unter bestimmten
#   Vorraussetzungen unberechtigterweise die Edit-Rechte an einer Sammlung erlangen könnte
#   (siehe auch den Kommentar in individuals/curatorship.rb). Deshalb muss im Falle einer
#   Curatorship-Erstellung an dieser Stelle die Rechte-Abfrage ausgesetzt werden.

module Rahel
  class EventManager
    def self.create_individual user, type, label, computed_label_fields: {}
      klass = type.constantize
      raise "Es handelt sich nicht um eine Individual-Klasse" unless klass <= Individual
      raise ForbiddenAction unless user.can_create_individual?(klass)

      ActiveRecord::Base.transaction(requires_new: true) do
        indi = klass.create(label: label)

        computed_label_fields.each do |k,v|
          set_property(user, indi, k.to_s, v, hide_on_global_list: true, check_permissions: false)
        end

        # Zeige auf der globalen Liste keine Erstellung von weak Individuals.
        rev = Revision.create_from_new_individual(indi, user, hide_on_global_list: indi.weak?)

        # Vergebe für weak Individuals keine Sichtbarkeit und keine Rechte, da diese von
        # den Revision-Receivers abhängen (siehe Kommentare in User#can_view_individual? und
        # User#can_edit_individual?).
        unless indi.weak?
          # Das neue Individual ist zunächst nur für Benutzer sichtbar, die mindestens so
          # stark sind wie der Ersteller. (Aber vergebe auch dann Sichtbarkeit "manager",
          # wenn der Ersteller ein Admin ist.)
          role = user.role == :admin ? :manager : user.role
          set_property(user, indi, "visible_for", role, hide_on_global_list: true,
                       check_permissions: false)

          if user.member?
            # Members dürfen im Allgemeinen nicht bearbeiten, aber die von ihnen selbst erstellten
            # Individual dürfen sie natürlich bearbeiten.
            set_property(user, user.person, "can_edit", indi, hide_on_global_list: true,
                         check_permissions: false)
          end
        end

        # Wird zur Zeit nicht benutzt, da keine Individuals inline erstellt werden.
        #value.parse_label objekt_label

        indi
      end
    end

    def self.update_individual user, indi, new_label, revision_id: nil
      ActiveRecord::Base.transaction(requires_new: true) do
        unless indi.is_a? Individual
          indi = Individual.find(indi)
        end
        
        raise ForbiddenAction unless user.can_edit_individual?(indi)
      
        if revision_id.present?
          rev = Revision.find(revision_id)
        else
          rev = Revision.new(user: user)
          rev.set_old_individual(indi)
        end

        indi.label = new_label
        indi.save!

        rev.set_new_individual(indi)

        if rev.old_label == rev.new_label
          rev.destroy
        else
          rev.set_strong_individual_fields
          rev.save!
        end

        # Muss hier die Revision zurückgeben, damit der Controller die Revison-Id wieder
        # mit AJAX an das Edit-Modal schicken kann.
        rev
      end
    end

    def self.delete_individual user, indi, hide_on_global_list: false, check_permissions: true
      if check_permissions
        raise ForbiddenAction unless user.can_delete_individual?(indi)
      end
      
      # check if ontology constant before starting to delete this indi's properties
      if indi.descriptive_id.present?
        raise ErrorController::UndeletableIndividual, "This Individual '#{indi.label}'(#{indi.id}) is an ontology constant as indicated by its non-empty descriptive_id value '#{indi.descriptive_id}' and thus must not be deleted."
      end

      # Delete all properties first.
      # Prüfe dabei *nicht*, ob das Subject ein leeres Label hat, denn wir werden das Subject
      # ja eh gleich löschen (ohne diese Anweisung würde eine Endlosschleife entstehen).
      indi.properties(reload: true).each do |prop|
        delete_property(user, prop, hide_on_global_list: true, check_permissions: false,
                        delete_subject_on_empty_label: false)
      end

      # Eigentlich sollten jetzt auch alle Properties weg sein, in denen der Individual das Objekt
      # ist. Dies ist aber nur dann der Fall, wenn immer das inverse Property im Datenmodell
      # eingetragen ist. Für den Fall, dass das irgendwo nicht so ist, löschen wir nun explizit
      # noch diese Properties, da wir sonst das Individual nicht löschen dürften (siehe den
      # before_destroy-Callback in models/rahel/individual.rb).
      indi.is_objekt(reload: true).each do |prop|
        delete_property(user, prop, hide_on_global_list: true, check_permissions: false)
      end

      if indi.destroy
        Revision.create_from_old_individual(indi, user, hide_on_global_list: hide_on_global_list)
      else
        # Individual konnte nicht gelöscht werden, zB weil die Aktion im before_destroy-Callback
        # abgebrochen wurde.
        raise Error, "Der Individual konnte leider nicht gelöscht werden."
      end
    end

    #
    # Properties
    #

    def self.create_property user, indi_id, predicate, value, objekt: {}, inline_indi: {}, other_indi: {}
      ActiveRecord::Base.transaction(requires_new: true) do
        indi = Individual.where(id: indi_id).first
        unless indi
          # Dies ist der Fall, dass es Subject noch nicht gibt, weil es ein weak Individual ist,
          # der bis jetzt noch keine Label-relevaten Properties hat. Für weitere Notizen siehe
          # "update_property".

          weak_type = inline_indi[:individual].singular_range_of(inline_indi[:predicate])
          indi = create_individual(user, weak_type, "")

          base_prop, _ = set_property(user, inline_indi[:individual],
                                      inline_indi[:predicate], indi,
                                      occured_at_id: inline_indi[:id])
        end

        if indi.type_of(predicate) == :objekt
          if objekt[:id].present?
            # Ein bestehendes Individual soll Objekt werden.
            value = Individual.find(objekt[:id])
          else
            # Wir müssen ein neues Objekt-Individual erstellen (inkl. Revision).
            # objekt[:type] ist typischerweise leer, wenn es sich um ein weak individual handelt.
            objekt[:type] ||= indi.singular_range_of(predicate)

            value = create_individual(user, objekt[:type], objekt[:label])
          end
        end

        if other_indi[:id] && other_indi[:predicate]
          other = Individual.find(other_indi[:id])
          _, r, _ = set_property(user, other, other_indi[:predicate],
                                  value, check_permissions: false)
          # Wir deaktivieren hier die Rechte-Abfrage, denn:
          # Ein Member, der ein Curatorship (hier: value) zu einer Sammlung (hier: indi) hinzufügt,
          # darf dies zwar (wenn er die Rechte entweder automatisch oder manuell bekam), aber er darf
          # eigentlich nicht dem Curatorship eine Person (hier: other) zuweisen (denn sonst könnte er
          # sich unerlaubterweise zum Curator mancher Sammlungen machen, siehe Kommentar in
          # curatorship.rb).
        end

        prop, rev = set_property(user, indi, predicate, value,
                                  occured_at_id: inline_indi[:id])

        # Weil jetzt erst das Curatorship-Label fertig ist, basteln wir nun noch etwas an der
        # Revision herum, die auf der lokalen Revisions-Liste für das "other_individual" (das ist der
        # Individual, der in der Auswahlliste ausgewählt wurde) angezeigt wird.
        if r
          r.new_objekt_label = value.label
          r.save!
        end

        [indi, prop, rev, base_prop]
      end
    end

    # Für Nicht-Objekt-Properties.
    # Benutzt *nicht* "indi.prop = value", sondern "prop.value = value", daher haben wir hier
    # nichts mit inversen Properties zu tun. Das ist aber Ok, da es sich nur um Nicht-Objekt-
    # Properties handelt.
    def self.update_data_property user, prop, value, revision_id: nil, occured_at_id: nil
      raise ForbiddenAction unless user.can_edit_property?(prop)

      ActiveRecord::Base.transaction(requires_new: true) do
        if value == "" || value.nil? || (value == false && prop.property_type != :bool)
          return delete_property(user, prop)
        end

        if revision_id.present?
          rev = Revision.find(revision_id)
        else
          rev = Revision.new(user: user)
          rev.set_old_property(prop)
        end

        prop.value = value
        prop.save!

        # Speichern nun noch den Subject-Individual, da sich sein Computed Label evtl. ändern muss.
        # Beispiel: first_name von Person oder name von WebResource
        prop.subject.save!

        rev.set_new_property(prop)
        rev.set_strong_individual_fields occured_at_id: occured_at_id
        rev.save!

        if rev.old_value == rev.new_value
          rev.destroy
        end

        rev
      end
    end

    # Für nicht-Objekt-Properties, Card-1,
    # die vorher leer waren und damit erst erstellt werden müssen
    # TODO: Starke Ähnlichkeit zu create_property, könnte man zusammenlegen
    def self.create_data_property user, individual_id, predicate, value, inline, revision_id=nil
      ActiveRecord::Base.transaction(requires_new: true) do
        indi = Individual.where(id: individual_id).first
        unless indi
          # Dies ist der Fall, dass einem leeren weak Individual (zB eine gerade hinzugefügte
          # WebResource) die ersten Daten eingetragen werden. Gehe dann davon aus, dass das
          # weak Individual direkt am Inline-Individual hängt. Das bedeutet, dass dieses
          # erst-erstellen-wenn-es-Daten-gibt-Feature nur für solche weak Individuals unterstützt
          # wird, die direkt an einem strong Individual hängen. (Es ist aber bis jetzt auch noch
          # nicht vorgekommen, dass an einem weak Individual ein weiteres weak Individual hängt.)
          #
          # Man beachte: Das ist eine kleine Asymmetrie zu dem Verhalten oben, denn dort wird dann
          # gelöscht, wenn das *Label* leer wird. (Das liegt daran, das auch gelöscht werden soll,
          # wenn es noch ein Property gibt, nämlich das "is_database"-Property zum strong
          # Individual.) Hier wird dagegen schon erstellt, wenn *irgendein* Property erstellt wird.
          # Wir gehen also hier davon aus, dass alle Nicht-Objekt-Properties, die einem Label-losen
          # weak Individual hinzugefügt werden, relevant für das Label sind. Zur Zeit ist das auch
          # so, mit einer Ausnahme: "manager" bei Curatorship. Das ist nicht Label-relevant,
          # aber Curatorships haben eh nie ein leeres Label, da ihr Label von den Revision-Receiver-
          # Individuals bestimmt wird, also der Person und der Sammlung. Deswegen stellt dieser Fall
          # kein Problem dar. Ich gehe davon aus, dass es allgemein so ist, dass eingegebene Daten
          # gespeichert werden sollen, egal, ob sie Label-relevant sind, oder nicht. Deshalb wird
          # sich die oben beschriebene Asymmetrie in der Praxis nicht bemerkbar machen.

          weak_type = inline[:individual].singular_range_of(inline[:predicate])
          indi = create_individual(user, weak_type, "")
          base_prop, _ = set_property(user, inline[:individual],
                                                              inline[:predicate], indi,
                                                              hide_on_global_list: true,
                                                              occured_at_id: inline[:id])
          # Verstecke diese Revision zu der Base-Property-Erstellung auf der globalen Liste, weil
          # sie nicht informativ ist, da das Label zu diesem Zeitpunkt noch leer ist.
        end

        prop, rev = set_property(user, indi, predicate, value,
                                                     revision_id: revision_id,
                                                     occured_at_id: inline[:id])

        [prop, rev, base_prop]
      end
    end

    def self.delete_property user, prop, check_permissions: true, hide_on_global_list: false,
                             delete_subject_on_empty_label: true
      ActiveRecord::Base.transaction(requires_new: true) do
        if check_permissions
          raise ForbiddenAction unless user.can_edit_property?(prop)
        end

        prop.destroy

        # TODO: Falls das löschen von Properties zu invaliden Individuals führen kann,
        # was momentan nicht der Fall ist, muss hier noch auf Validität geprüft werden.

        # Speichern nun noch den Subject-Individual, da sich sein Computed Label evtl. ändern muss.
        # Beispiel: first_name von Person oder name von WebResource
        prop.subject.save!

        rev = Revision.create_from_old_property(prop, user, hide_on_global_list: hide_on_global_list)

        # Wenn es ein inverses gibt, dann auch löschen (inkl. Revision).
        if prop.inverse
          prop.inverse.destroy
          Revision.create_from_old_property(prop.inverse, user, inverse: true,
                                            hide_on_global_list: hide_on_global_list)
        end

        # Prüfe, ob der Wert ein weak Individual ist, und das Prädikat beim weak Individual
        # als "revision_receiver" gekenzeichnet ist. In diesem Fall das weak Individual löschen.
        # Der Test auf "revision_receiver" ist nötig, falls zum Beispiel eine Stadt gelöscht wird.
        # Dann werden auch alle Properties gelöscht, unter anderem auch die, bei denen Addresses
        # (ein weak Individual) das Objekt sind. Die Adressen sollen aber *nicht* gelöscht werden.
        # Ein Adresse soll nur dann gelöscht werden, wenn ihr "Träger" gelöscht wird, also zB die
        # Sammlung, von der sie die Adresse ist.
        val = prop.value
        if val.is_a?(Individual) && val.weak?
          inverse_predicate = prop.subject.inverse_of(prop.predicate)
          if val.predicates[inverse_predicate] &&
              val.predicates[inverse_predicate][:receives_revisions]
            delete_individual(user, val, hide_on_global_list: true, check_permissions: false)
          end
        end
        # Achtung: Der Trigger, der beim Löschen eines Propertys auch weak Individuals löscht,
        # die danach "lonely" sind, funktioniert nur bei dem Property, dass das weak Individual
        # als *value* hat (nicht als *subject*). Letzteres Property wird natürlich auch gelöscht,
        # da es das Inverse des anderen ist. (Dies sollte in der Praxis, sowohl in UI als auch in
        # Kommandozeile) keine Probleme machen.)

        if delete_subject_on_empty_label && prop.subject.weak?
          # Prüfe, ob das *Subject* ein weak Individual ist, dessen Label nun leer ist
          # (speichere zunächst das Subject, damit das Label neu berechnet wird).
          prop.subject.save!
          if prop.subject.label.empty?
            # Lösche in diesem Fall das Subject.
            delete_individual(user, prop.subject, hide_on_global_list: true, check_permissions: false)
          end
        end

        rev
      end
    end



    private

    # Für "indi.prop = value"
    # Die Revision-Id brauchen wir hier für den Fall: Nicht-Objekt-cardOne-Property.
    def self.set_property user, indi, predicate, value, revision_id: nil, occured_at_id: nil,
                          check_permissions: true, hide_on_global_list: false
      ActiveRecord::Base.transaction(requires_new: true) do
        if check_permissions
          raise ForbiddenAction unless user.can_edit_property?(predicate, indi)
        end

        if revision_id.present?
          rev = Revision.find(revision_id)
        else
          rev = Revision.new(user: user, hide_on_global_list: hide_on_global_list)
        end
        inverse_rev = Revision.new(user: user, inverse: true)

        # Wert setzen. Dabei wird ggf. auch das inverse Property gesetzt.
        prop = indi.send("#{predicate}=", value)
        
        # Speichern nun noch den Subject-Individual, da sich sein Computed Label evtl. ändern muss.
        # Beispiel: first_name von Person oder name von WebResource
        if prop && prop.subject
          prop.subject.save!
        end

        # prop ist nil bzw. destroyed, wenn value nil oder "" war, oder es sich um ein
        # Duplikat handelte, oder wenn prop zwar valide war, aber indi nicht.
        if prop && !prop.destroyed?
          rev.set_new_property(prop)
          rev.set_strong_individual_fields occured_at_id: occured_at_id
          rev.save!
          if prop.inverse
            inverse_rev.set_new_property prop.inverse
            # Hier kein "occured_at_id", da eh nicht auf globaler Liste angezeigt:
            inverse_rev.set_strong_individual_fields
            inverse_rev.save
          end
        end

        # inverse_rev wird in UpdateController#create_property bei der Erstellung von Curatorships
        # benötigt (siehe Kommentar dort).
        [prop, rev, inverse_rev]
      end
    end
  end
end

    # Der folgende Code gehört zu "set_property" und wird dann relevant,
    # wenn ein cardOne-Property ersetzt wird, dass heißt es
    # wird ein Wert zugewiesen, wobei bereits ein Wert existiert. Dies kommt aber zur Zeit in der
    # UI nicht vor, deswegen ist er auskommentiert. Falls dieser Fall wieder möglich sein soll (zum
    # Beispiel in der Console), dann den Code wieder aktivieren und testen!
    ## Revisionen vorbereiten.
    #if indi.cardinality_of(predicate) == 1
    #  # Müssen das Property jetzt schon holen, denn bei cardOne "predicate=" wird ja überschrieben.
    #  prop = Property.where(subject_id: indi.id, predicate: predicate).first
    #  if prop
    #    rev.set_old_property(prop)
    #
    #    # Wenn das Property ein altes inverse hat, dann wird das gelöscht werden. Also Revision.
    #    if prop.inverse
    #      Revision.create_from_old_property(prop.inverse, user)
    #    end
    #  end
    #
    #  # Auch das neue inverse Property holen.
    #  inverse_prop = Property.where(subject_id: objekt_id,
    #                                predicate: indi.inverse_of(predicate)).first
    #  if inverse_prop
    #    inverse_rev.set_old_property(inverse_prop)
    #
    #    # Wenn das neue Inverse ein altes Inverse hat, dann wird das gelöscht werden.
    #    #Also Revision.
    #    if inverse_prop.inverse
    #      Revision.create_from_old_property(inverse_prop.inverse, user)
    #    end
    #  end
    #end
