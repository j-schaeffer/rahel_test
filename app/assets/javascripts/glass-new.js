// glass-new.js
// Glass-Modul für das Erstellen von Individuals
// Anmerkung: Die Organisation des Glass-Moduls orientiert sich an diesem Pattern:
// http://molily.de/js/organisation-module.html#feste-kopplung

$(document).on("turbolinks:load", function(){

  (function (G) {
  	// Submodule init function
  	G.submoduleInit.push(function () {
  		// New Modal
  	    $(".js-show-new-modal").click(function(event) {
  	      event.preventDefault();
  	      showNewModal();
  	    });
  	});

  	function showNewModal() {
      $.get("/new", function(html) {

        // Show new modal
        G.modal = $(html);
        $("body").append(G.modal);
        G.modal.modal("show");

        bindNewModalEvents(G.modal);

      }).fail(makeErrorAlerter("Modal konnte nicht geladen werden"));
    }

    function bindNewModalEvents(modal) {
      // Basic Modal Events
      G.bindModalEvents(modal);

      // Typ-Selektion
      bindTypeSelectionEvents(modal);

      modal.find("input.range-filter").keyup(G.rangeFilterInputKeyUpHandler);

      modal.find("form").submit(preventEmptyLabel);
    }

    function bindTypeSelectionEvents(modal) {
      modal.find(".js-indi-typeselect").click(function() {
        modal.find("#typeselect").val($(this).val());
        modal.find("#js-selected-type-div .js-selected-type").html($(this).html());
        // Suchbox leeren und keyup-event triggern, damit der Eventhandler für den range-filter anspringt
        modal.find("#js-typeselect-container input.range-filter").val("").keyup();
        // Typ-Auswahl ausblenden
        modal.find("#js-typeselect-container").hide();
        // Ausgewählten Typ-Container einblenden
        modal.find("#js-selected-type-div").show();

        if ($(this).val() == "Person") {
          modal.find(".person-fields").show();
          modal.find(".label-field").hide();
        } else {
          modal.find(".person-fields").hide();
          modal.find(".label-field").show();
        }

        modal.find(".js-create-individual").prop('disabled', false);
      });

      modal.find("#js-selected-type-div .js-back-to-typeselection").click(function() {
        // Submit-Button disabeln
        modal.find(".js-create-individual").prop('disabled', true);
        // Typauswahl einblenden
        modal.find("#js-typeselect-container").show();
        // gewählten Typ leeren
        modal.find("#typeselect").val("");
        modal.find("#js-selected-type-div .js-selected-type").html("Typ");
        // und ausblenden
        modal.find("#js-selected-type-div").hide();
        // Falls Person angewählt war, wieder das label-field anzeigen
        modal.find(".person-fields").hide();
        modal.find(".label-field").show();
      });
    }

    function preventEmptyLabel(event) {
      // Verhindere, dass Individuals mit leerem Label erstellt werden.
      // Ansonsten das reguläre Event stattfinden lassen (nicht verhindern).
      if (G.modal.find("#typeselect").val() == "Person") {
        if (G.modal.find("input[name=name]").val().trim() == "" &&
            G.modal.find("input[name=first_name]").val().trim() == "") {
          event.preventDefault();
          alert("Bitte geben sie einen Namen an.");
        }
      } else {
        if (G.modal.find("input[name=label]").val().trim() == "") {
          event.preventDefault();
          alert("Bitte geben sie eine Bezeichnung an.");
        }
      }
    }

  })(Glass);
});