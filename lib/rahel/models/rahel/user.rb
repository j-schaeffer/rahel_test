module Rahel
  class User < ActiveRecord::Base
    ROLES = %i(
      public
      member
      manager
      admin
    )

    # Include default devise modules. Others available are:
    # :confirmable, :lockable, :timeoutable and :omniauthable
    devise :database_authenticatable, :registerable,
           :recoverable, :rememberable, :trackable, :validatable

    # Die Person, zu der dieser User gehört.
    belongs_to :person, foreign_key: "individual_id", class_name: "Rahel::Individual"
    
    # prevent destruction of Users
    def destroy
      raise ForbiddenAction, "Users must not be destroyed. Although Users are not Individuals like you and me it is wrong to destroy them. If you are a monster and want to kill this User anyways, please contact your database administrator ;)"
    end

    def to_s
      # TODO Format "V. Nachname"
      return person.label if person

      str = email
      str = name unless name.blank?
      str = first_name[0] + ". " + str if !first_name.blank? && first_name.length > 0
      str = str[0..13] + "..." if str.length > 16
      str
    end

    # Roles are handled as symbols, just like actions.
    def role
      super.to_sym
    end

    def can_view_individual? individual
      if can_edit_individual? individual
        # wenn man die Bearbeitungsrechte für ein Individual hat, dann darf man
        # das Individual natürlich auch sehen
        true
      elsif individual.weak?
        # Um einen weak Individual zu sehen, muss man *alle* Revision-Receivers sehen
        # dürfen. Dies wird zB relevant bei der Frage, ob der Benutzer ein "curator"-Property
        # sehen darf. Dies wird davon abhängig gemacht, ob der Objekt des Propertys, also das
        # Curatorship-Individual, sichtbar ist.
        individual.revision_receivers.all? { |indi, _| can_view_individual?(indi) }
      else
        # Hole zunächst die Mindest-Rolle, die die Individual-Klasse für die Sichtbarkeit fordert.
        min_role_by_class = individual.class.minimum_role_required(:view)

        # Schaue, ob für den Individual eine Sichtbarkeit gesetzt ist.
        min_role_by_indi = individual.visible_for_value

        # Wenn ja, dann muss man die haben, ansonsten zählt, was von der Klasse gefordert wird.
        min_role_by_indi ? at_least?(min_role_by_indi.to_sym) : at_least?(min_role_by_class)
      end
    end

    def can_create_individual? individual_class
      if individual_class.weak?
        # Weak Individuals können von allen erstellt werden, die mehr als public sind.
        !self.public?
      else
        at_least?(individual_class.minimum_role_required(:create))
      end
    end

    def can_edit_individual? individual
      if individual.weak?
        # Wenn man einen weak Individual bearbeiten möchte, dann darf man das genau dann,
        # wenn man einen der Revision-Receivers bearbeiten darf. So darf man zB Curatorships
        # bearbeiten, für die man die Sammlung bearbeiten darf (zB weil man dort als Curator
        # eingetragen ist, möglicherweise in einem anderen Curatorship).
        individual.revision_receivers.any? { |indi, _| can_edit_individual?(indi) }
      else
        # Hole zunächst die Mindest-Rolle, die die Individual-Klasse für die Bearbeitung fordert.
        min_role_by_class = individual.class.minimum_role_required(:edit)

        # Man kann die Edit-Erlaubnis auf drei Arten bekommen, wobei eine ausreicht.
        # (1) Man hat die von der Klasse geforderte Rolle.
        at_least?(min_role_by_class) ||
          # (2) Man hat das Edit-Recht explizit zugewiesen bekommen.
          (person && person.can_edit.where(objekt_id: individual.id).any?) ||
          # (3) Das Individual gehört zu denen, die automatisch bearbeitbar sind.
          (person && person.automatically_editable.include?(individual))
      end
    end

    def can_delete_individual? individual
      # some individuals must not be deleted 
      # e.g. Persons that are connected with a Rahel::User (revisions' author must be permanent)
      if Rahel::User.where(individual_id: individual.id).any?
        return false
      end
      # Hier zählt nur die Mindest-Rolle, die die Individual-Klasse fordert.
      min_role_by_class = individual.class.minimum_role_required(:delete)
      at_least?(min_role_by_class)
    end

    def can_view_property? property_or_predicate, subject=nil
      # Man kann entweder ein Property als Argument übergeben, oder ein Predicate zusammen mit
      # einem Individual. Die letztere Option ist mindestens in einem Fall nötig, nämlich dann,
      # wenn wir in Maya in _person.html.erb entscheiden müssen, ob wir die automatisch
      # bearbeitbaren Individuals anzeigen wollen. Dies soll davon abhängen, ob der Benutzer
      # eventuelle "can_edit"-Properties sehen *könnte*, wir können uns hier also nicht darauf
      # verlassen, dass es tatsächlich ein Property gibt, das wir hier übergeben könnten. (Wenn
      # das erste Argument ein Property ist, dann wird ein eventuelles zweites Argument ignoriert.)
      # Finde deshalb zunächst heraus, was übergeben wurde.
      if property_or_predicate.is_a?(Property)
        property = property_or_predicate
        predicate = property.predicate
        subject = property.subject
      else
        predicate = property_or_predicate
        unless subject.is_a?(Individual)
          raise "Es muss zu einem Predicate immer ein Subject angegeben werden."
        end
      end

      # Entweder muss keine Rolle angegeben sein (per Default alle Preds sichtbar),
      # oder man muss mindestens die geforderte Rolle haben.
      r = subject.class.visible_for(predicate)
      visibility_by_predicate = (
        r.nil? || at_least?(r) ||
        # Oder Spezial-Recht: Man kann sehen, wen man selber bearbeiten darf
        (predicate == "can_edit" && subject == person)
      )

      if property && property.objekt?
        # Wenn es sich um ein Objekt-Property handelt, dann muss zusätzlich das Objekt des
        # Propertys sichtbar sein.
        visibility_by_predicate && can_view_individual?(property.objekt)
      else
        visibility_by_predicate
      end
    end

    # Bei Properties werden :create, :edit und :delete nicht wirklich unterschieden.
    def can_edit_property? property_or_predicate, subject=nil
      # Auch hier kann man entweder ein Property als Argument übergeben, oder ein Predicate
      # zusammen mit einem Individual. (Wenn das erste Argument ein Property ist, dann wird ein
      # eventuelles zweites Argument ignoriert.) Finde deshalb zunächst heraus, was übergeben wurde.
      if property_or_predicate.is_a?(Property)
        property = property_or_predicate
        predicate = property.predicate
        subject = property.subject
      else
        predicate = property_or_predicate
        unless subject.is_a?(Individual)
          raise "Es muss zu einem Predicate immer ein Subject angegeben werden."
        end
      end

      r = subject.class.editable_for(predicate)

      # (1) Man muss das Subject bearbeiten können UND
      can_edit_individual?(subject) &&
        # (2) man muss das Property sehen können UND
        can_view_property?(property_or_predicate, subject) &&
        # (3) WENN bei der Subject-Klasse eine Mindestrolle angegeben ist, dann muss man diese
        # mindestens haben.
        (r.nil? || at_least?(r))
    end

    # zB invite_user
    def can? action
      raise "Bitte Symbole für die Actions benutzen" unless action.is_a? Symbol

      # Bei Individual sind die Rechte für solche Actions angegeben, die sich nicht unbedingt auf
      # ein konkretes Individual beziehen (zB das Ansehen bestimmter Bereiche der Anwendung oder
      # :invite_user).
      at_least?(Individual.minimum_role_required(action))
    end

    def can_view_revision? rev
      # manager dürfen alle Revisionen sehen
      return true if self.at_least? :manager
      
      indis = [rev.old_individual, rev.new_individual, rev.subject, rev.old_objekt, rev.new_objekt].reject(&:nil?)
      # Um eine Revision sehen zu dürfen muss man
      # 1. alle direkt beteiligten Individuals sehen dürfen
      # 2. wenigstens eines dieser Individuals bearbeiten dürfen
      indis.all? {|indi| can_view_individual? indi} &&
      indis.any? {|indi| can_edit_individual? indi}
    end

    # Feststellen, ob der User mindestens die benötigte Rolle hat
    def at_least? required_role
      my_index = ROLES.index(role)
      required_index = ROLES.index(required_role)

      my_index && required_index && my_index >= required_index
    end

    # Definiere Methoden wie "current_user.member?"
    ROLES.each do |r|
      define_method "#{r}?" do
        role == r
      end
    end

    # Ein Benutzer, der benutzt wird, wenn kein Benutzer eingeloggt ist
    def self.anonymous_user
      where(email: "anonymous@kwus.org").first || create_anonymous_user
    end
    
    # Gibt zurück, ob der Einladungsprozess vollendet ist
    def registration_complete?
      # betrachte den Registrierungsvorgang als beendet sobald ein Passwort gesetzt wurde
      self.encrypted_password.present?
    end
    
    # Gibt zurück, ob die eingeladene Person den Link bereits angeklickt hat
    def clicked_invitation_link?
      self.clicked_invitation_link
    end
    
    # returns the datetime of the request of name action if this user's person has property
    # 'request_#{action}' pointing to individual, nil otherwise
    def requested action, individual
      unless self.person.present?
        raise ErrorController::UserWithoutPerson, "current_user #{cur}:#{cur.id} has no associated Person"
      end
      requests = self.person.send("request_#{action}")
      if !requests.nil? && !requests.empty?
        requests.each do |prop|
          indi = prop.value
          if indi == individual
            return prop.created_at.to_datetime
          end
        end
      end
      nil
    end

    def invited_by_user
      self.class.find(invited_by) if invited_by
    end

    private

    def self.create_anonymous_user
      u = new(email: "anonymous@kwus.org", name: "Anonymous", role: "public")
      u.save(validate: false)
      u
    end
  end
end
