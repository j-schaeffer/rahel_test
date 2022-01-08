// glass-edit.js
// Glass-Modul für das Ändern von Individuals/Properties
// Anmerkung: Die Organisation des Glass-Moduls orientiert sich an diesem Pattern:
// http://molily.de/js/organisation-module.html#feste-kopplung

(function (G) {
	// Submodule init function
	G.submoduleInit.push(function () {
    // Inline editing
    if (window.location.href.indexOf("mode=edit") < 0) {
      $("#myonoffswitch").attr("checked", false);
    }
    $("#myonoffswitch").click(function() {
      if ($(".onoffswitch-checkbox").prop("checked") == true) {
        enterEditMode();
      } else {
        leaveEditMode();
      }
    });
    if ($(".glass-individual").hasClass("edit-mode")) {
      enterEditMode();
    }

    $(".js-collapse-property-group").click(propertyGroupCollapseClickHandler);
		
		// experimental hotkey <ctrl>+<b> support for edit-mode
		$(document).keydown(function(e) {
	    // ctrl+b pressed?
	    if(e.which == 66 && e.ctrlKey) {
				e.preventDefault();
				$('#myonoffswitch').click();
	    }
		});
	});


  //
  // Modulweite Hilfsvariablen
  //

  var modal;
  var leftCol;
  var rightCol;
  var timeoutID;

  // Loading spinner options
  var spinnerOptions = {
    lines: 13, // The number of lines to draw
    length: 20, // The length of each line
    width: 10, // The line thickness
    radius: 30, // The radius of the inner circle
    corners: 1, // Corner roundness (0..1)
    rotate: 0, // The rotation offset
    direction: 1, // 1: clockwise, -1: counterclockwise
    color: '#000', // #rgb or #rrggbb or array of colors
    speed: 1, // Rounds per second
    trail: 60, // Afterglow percentage
    shadow: false, // Whether to render a shadow
    hwaccel: false, // Whether to use hardware acceleration
    className: 'spinner', // The CSS class to assign to the spinner
    zIndex: 2e9, // The z-index (defaults to 2000000000)
    top: '70px', // Top position relative to parent
    left: '50%' // Left position relative to parent
  };

  // Loading spinner for property group expansion
  var expandPropGroupSpinnerOpts = {
    lines: 15, // The number of lines to draw
    length: 5, // The length of each line
    width: 3, // The line thickness
    radius: 5, // The radius of the inner circle
    scale: 1, // Scales overall size of the spinner
    corners: 1, // Corner roundness (0..1)
    color: '#1f2d54', // #rgb or #rrggbb or array of colors
    opacity: 0.25, // Opacity of the lines
    rotate: 0, // The rotation offset
    direction: 1, // 1: clockwise, -1: counterclockwise
    speed: 1, // Rounds per second
    trail: 40, // Afterglow percentage
    fps: 20, // Frames per second when using setTimeout() as a fallback for CSS
    zIndex: 2e9, // The z-index (defaults to 2000000000)
    className: 'spinner', // The CSS class to assign to the spinner
    top: '10px', // Top position relative to parent
    left: '50%', // Left position relative to parent
    shadow: false, // Whether to render a shadow
    hwaccel: false, // Whether to use hardware acceleration
    position: 'relative' // Element positioning
  }


  //
  // Edit-Mode switching
  //

  function enterEditMode() {
    $(".glass-individual")
      .addClass("edit-mode")
      .find(".property-group.editable")
      .click(propertyGroupDivClickHandler)
      .tooltip("enable");
    $(".js-collapse-property-group")
      .unbind("click");
		// hide infosystem-tooltip-anchors/questionmarks
		$(".js-tooltip").hide();
		// hide external-link icons
		$(".linker").hide();
  }

  function leaveEditMode() {
    $(".glass-individual")
      .removeClass("edit-mode")
      .find(".property-group.editable")
      .unbind("click")
      .tooltip("disable");
    $(".js-collapse-property-group")
      .click(propertyGroupCollapseClickHandler);
		// show infosystem-tooltip-anchors/questionmarks
		$(".js-tooltip").show();
		// show external-link icons
		$(".linker").show();
  }


  //
  // Inline Trigger
  //
  function propertyGroupDivClickHandler(event) {
    var predicate = $(this).data("predicate");
    var individualId = $(this).data("individual-id");

    // get modal html and show it
    $.get("/edit", { predicate: predicate, individual_id: individualId }, function(html) {
      modal = $(html);
      
      G.modal = modal // TODO: Optimize

      $("body").append(modal);
      modal.modal("show");

      leftCol = modal.find(".left-column");
      rightCol = modal.find(".right-column");

      G.bindModalEvents(modal);

      // Blende Revision Message im Modal Footer aus, sobald ein Input Element den Fokus verliert
      modal.focusout(emptyRevisionMessage);
      modal.find("select,input,textarea").focusout(emptyRevisionMessage);
      
      bindPropertyEvents(modal);
      showCorrectButton();
    }).fail(makeErrorAlerter("Modal konnte nicht geladen werden"));

    // Ist nötig, da in dem Div möglicherweise ein Link steht.
    event.preventDefault();
  }

  function propertyGroupCollapseClickHandler(event) {
    var target = $(this).data("target");
    var predicate = $(this).data("predicate");
    var sortmode = $(this).data("sortmode");
    
    if (!$(target).hasClass("synced")) {
      var spinner = new Spinner(expandPropGroupSpinnerOpts).spin($(target)[0]);
      $.get(window.location.pathname, {expand: predicate, sortmode: sortmode}, function(html) {
        spinner.stop();
        $(target).html(html);
        $(target).addClass("synced");
        // attach tooltip eventhandlers
        $(target).find('.js-tooltip').each(function() {
          if ( typeof(attachInfoTooltip) == "function" ) {
            attachInfoTooltip(this);
          }
        });
      }).fail(makeErrorAlerter("Konnte Eigenschaften nicht laden."));
    }

    var swap = $(this).data("alt-text");
    $(this).data("alt-text", $(this).html());
    $(this).html(swap);

    $(target).collapse("toggle");
  }


  //
  // Binding von Modal-Events
  //
  function bindPropertyEvents(div) {
    // "div" ist entweder das Modal nachdem es gerade geöffnet wurde
    // oder ein Property-Div, dass per Ajax nachgeladen wurde
    
    // Löschen einer Card-Many Property
    div.find("button.delete-property").click(function() {
      deleteProperty($(this).closest(".property"));
    });

    // Submit für Daten-Properties
    div.find("form.update-property").submit(function(event) {
      event.preventDefault();
      updateProperty($(this));
    });

    // Objekt-Property-Eintrag in der linken Spalte
    // oder Card-Many Daten-Property
    div.find("div.summary.editable").click(function() {
      showPropertyForm($(this).parent());
    });

    //// Einspaltige Modals

    // Validierung für Card-Many Daten-Properties
    div.find("form.create-property input").on("input", function(event) {
      event.preventDefault();
      validateProperty($(this).closest('form'));
    });

    // Absenden eines Card-Many Daten-Properties
    div.find("form.create-property").submit(function(event) {
      event.preventDefault();
      createDataProperty($(this));
    });

    //// Linke Spalte

    // Hinzufügen einer Card-Many Objekt-Property
    div.find("button.add").click(function() {
      showRange();
    });

    // Löschen und neu hinzufügen einer Card-One Objekt-Property
    div.find("button.replace").click(function() {
      deleteProperty(leftCol.find(".property:first"), showRange);
    });

    //// Rechte Spalte

    // Hinzufügen von neuen Objekt-Property Relationen
    div.find(".existing-individual").click(createObjektPropertyButtonClickHandler);

    //// Submit Trigger
		
		// Submit-Trigger für alles außer Date-Ranges
    // Input- und Text-Areas führen nach einem Delay,
    // Fokuswechsel oder Keycode (s.u.) zum Submit der Form
    div.find("form.update-property input:not(.date), textarea")
      .keyup(updatePropertyInputKeyUpHandler)
      .focusout(function() { $(this.form).submit(); })
			.keydown(function(e) {
      if (e.keyCode == 13 && (e.metaKey || e.ctrlKey)) {
        // submit on Cmd-Enter bzw. Ctrl-Enter
        $(this.form).submit();
      }
    });
		
		// Submit-Trigger für Date-Ranges
		// Der Bootstrap-Datepicker scheint einen kleinen Bug zu haben. Wenn die Option
		// autoclose auf true gesetzt ist, dann feuert auf dem zugehörigen <input> Element
		// das Event "focusout" noch bevor das Datum ins <input> geschrieben wird. Das führt
		// dazu, dass ein updateProperty mit einem leeren Wert abgeschickt wird. Daher werden
		// hier input.date-Elemente seperat behandelt.
		div.find("form.update-property input.date, textarea")
      .keyup(updatePropertyInputKeyUpHandler)
      .on("change", function() { $(this.form).submit(); })
			.keydown(function(e) {
      if (e.keyCode == 13 && (e.metaKey || e.ctrlKey)) {
        // submit on Cmd-Enter bzw. Ctrl-Enter
        $(this.form).submit();
      }
    });
		
    // Ändern einer Checkbox führt zum sofortigen Submit
    div.find("form.update-property input[type=checkbox]")
      .change(function() {
        $(this.form).submit();
      });

    // Ändern einer Auswahlliste führt zum sofortigen Submit
    div.find("form.update-property select")
      .change(function() {
        $(this.form).submit();
      });

    // RangeFilter für filterbare Listen von Individuals
    div.find("input.range-filter").keyup(G.rangeFilterInputKeyUpHandler).first();
    
    // call datepicker() on container .input-daterange to activate date-range logic
    div.find("input.date").datepicker({
      language: 'de',
			autoclose: true // close the datepicker immediately when a date is selected.
    });

    // Blende Revision Message im Modal Footer aus, sobald ein Input Element den Fokus verliert
    div.focusout(emptyRevisionMessage);
    div.find("select,input,textarea").focusout(emptyRevisionMessage);
  }


  //
  // Edit-Form und Ranges anzeigen
  //

  // Nach Auswählen einer Property aus der linken Spalte
  // oder einer bestehenden Card-Many Daten-Property
  function showPropertyForm(prop) {
    if (prop.parents(".left-column").length > 0) {
      // Bei Card-Many Objekt-Properties die Selected-Class tauschen
      modal.find(".selected").removeClass("selected");
      prop.find(".summary").addClass("selected");

      // Formular für rechte Spalte holen und einbetten
      $.get("/edit/property", { id: prop.data("id") }, function(html) {
        prop = $(html);
        prop.addClass("expanded");
        bindPropertyEvents(prop);
        rightCol.html(prop);
      }).fail(makeErrorAlerter("Formular konnte nicht geladen werden."));
    } else {
      // Bei Card-Many Daten-Properties die Form anstelle der Summary einblenden
      prop.addClass("expanded");
    }
    prop.find("input:not(.date):visible:first").focus();
  }

  // Range von Objekt-Properties anzeigen
  function showRange() {
    var indiId = modal.data("individual-id");
    var rangePredicate = modal.data("range-predicate");
    var weakType = modal.data("weak-type");
    var predicate = modal.data("predicate");

    var spinner = (new Spinner(spinnerOptions)).spin(rightCol[0]);

    if (weakType == "") {
      // Strong-Individuals die an dieser Stelle nicht bearbeitet werden sollen
      // Zum Beispiel Concept
      $.get("/edit/range", { individual_id: indiId, predicate: predicate }, function(html) {
        var range = $(html);
        rightCol.html(range);
        range.find("input.range-filter").keyup(G.rangeFilterInputKeyUpHandler).first().focus();
        range.find(".existing-individual").click(createObjektPropertyButtonClickHandler);
				range.find('.js-tooltip').each(attachTooltip);
      }).fail(makeErrorAlerter("Die Range konnte nicht geladen werden"));
    } else if (rangePredicate == "") {
      // Weak-Individuals, deren Properties an dieser Stelle bearbeitet werden können
      // Zum Beispiel WebResource
      $.get("/edit/weak_individual_form", { type: weakType }, function(html) {
        // Evtl. bestehende Auswahl aufheben
        modal.find(".selected").removeClass("selected");

        // right column
        var indi = $("<div>" + html + "</div>");
        bindPropertyEvents(indi);
        rightCol.html(indi);
        indi.find("input:visible:first").focus();
        // in case of a contained range, attach event handlers
        rightCol.find("input.range-filter").keyup(G.rangeFilterInputKeyUpHandler);
      }).fail(makeErrorAlerter("Konnte das Formular nicht laden"));
    } else {
      // Weak-Individuals, für die es ein weiteres Strong-Individual gibt
      // Zum Beispiel Curatorship
      $.get("/edit/range", { type: weakType, predicate: rangePredicate }, function(html) {
        var range = $(html);
        rightCol.html(range);
        range.find("input.range-filter").keyup(G.rangeFilterInputKeyUpHandler).focus();
        range.find(".existing-individual").click(createRangeIndividualClickHandler);
				range.find('.js-tooltip').each(attachTooltip);
      }).fail(makeErrorAlerter("Die Range konnte nicht geladen werden"));      
    }
		
		/**
		 * Attaches the qtips on ranges in edit-modal; they contain the individual- * specific info-texts if present; Assumes to be called with context of
		 * a dom element, that is followed by an element with class .tooltip-content
		 * and with the tooltip content as content ;)
		 */
		function attachTooltip() {
			$(this).qtip({
				content: {
					text: $(this).next('.tooltip-content')
				},
				show: {
					delay: 1300
				},
				position: {
					my: 'top left',
					at: 'bottom left',
					adjust: {
						x: 10
					}
				},
				style: {
					classes: 'qtip-bootstrap individual-predicate-tooltip'
				}
			});
		}
  }


  //
  // Submit-Functions
  //

  // Erstellung einer Daten-Property
  function createDataProperty(form) {
    var input = form.find("input");

    var val = $(input).val();
    // do nothing when no input value
    if (val == undefined || val == "" || val == null) {
      return;
    }
    $.ajax({
      url: "/update/property",
      method: "POST",
      dataType: "json",
      data: {
        value: val,
        predicate: form.data("predicate"),
        individual_id: form.data("individual-id"),
        inline_predicate: modal.data("predicate"),
        inline_individual_id: modal.data("individual-id")
      },
      success: function(data) {
        var prop = $(data.edit_html);
        bindPropertyEvents(prop);
        prop.data("revision-id", data.revision_id);
        form.before(prop);
        setRevisionMessage(data.revision_message);
        deploy(data.inline_html);
        input.val("").focus();
      },
      error: makeErrorAlerter("Property konnte nicht erstellt werden")
    });
  }

  // Erstellung einer Objekt-Property die zwei Strong-Indis verknüpft
  function createObjektPropertyButtonClickHandler(event) {
    var btn = $(this);
    var form = $(this.form);
    var input = form.find("input");

    // das ":last" ist ein Hack für using_aids_collection. Gibt es bessere Möglichkeit,
    // das richtige .properties-Div zu finden?
    var props = modal.find(".properties:last");
    var cardOne = form.hasClass("cardinality-one");
    var valueSet = (props.children().length != 0);
    $.ajax({
      url: "/update/property",
      method: "POST",
      dataType: "json",
      data: {
        objekt_id: btn.data("objekt-id"),
        objekt: { label: input.val(), type: btn.data("type") },
        predicate: form.data("predicate"),
        individual_id: form.data("individual-id"),
        inline_predicate: modal.data("predicate"),
        inline_individual_id: modal.data("individual-id")
      },
      success: function(data) {
        var prop = $(data.edit_html);

        // Ersetzen in Maya nicht möglich
        //if (cardOne) {
        //  props.empty();
        //  form.find(".existing-individual").removeAttr("disabled");
        //
        //  if (!valueSet) {
        //    form.find(".glyphicon").removeClass("glyphicon-plus").addClass("glyphicon-retweet");
        //    // TODO "hinzufügen" -> "ersetzen"
        //  }
        //}
        props.append(prop);
        bindPropertyEvents(prop);

        if (btn.hasClass("existing-individual")) {
          // Wollen alle Buttons ausgrauen, die den gleichen Individual repräsentieren
          // (es können mehrere sein, wenn die Range hierachisch angezeigt wird).
          var objektId = btn.data("objekt-id");
          form.find(".existing-individual[data-objekt-id=" + objektId + "]")
              .attr("disabled", "disabled");
        } else if (data.range) {
          var newRange = $(data.range);
          modal.find(".range").replaceWith(newRange);
          bindPropertyEvents(newRange);
        }

        // In Maya werden cardOne-Ranges (zB Address.location) gleich wieder ausgeblendet, da
        // ersetzen nicht möglich ist.
        if (cardOne) {
          modal.find(".create-objekt-property").remove();
        }

        handleBaseProperty(data, prop.data("individual-id"));
        setRevisionMessage(data.revision_message);
        deploy(data.inline_html);
        input.select().focus();
      },
      error: function(data) {
        if (data.responseJSON) {
          if (data.responseJSON.errors) {
            setRevisionMessage(data.responseJSON.errors.join("<br>"));
          } else {
            setRevisionMessage("Die Änderungen konnten leider nicht gespeichert werden.");
          }
        } else if ($("body").data("rails-env") == "development") {
          setRevisionMessage("(Development): Turn off 'consider_all_links_local' to display error messages.")
        }
      }
    });
    event.preventDefault();
  }

  // Erstellung eines Weak-Indis, das zwei Strong-Indis verknüpft
  function createRangeIndividualClickHandler(event) {
    var rangeBtn = $(this);

    var indiId = modal.data("individual-id");
    var predicate = modal.data("predicate");

    var objektId = rangeBtn.data("objekt-id");
    var inverseRangePredicate = modal.data("inverse-range-predicate");

    $.ajax({
      url: "/update/property",
      method: "POST",
      dataType: "json",
      data: {
        inline_individual_id: indiId,
        inline_predicate: predicate,
        individual_id: indiId,
        predicate: predicate,
        other_individual_id: objektId,
        other_individual_predicate: inverseRangePredicate,
      },
      success: function(data) {
        addPropertyToLeftColumn(data.edit_html);

        // right column
        prop = $(data.edit_html);
        prop.addClass("expanded");
        bindPropertyEvents(prop);
        rightCol.html(prop);
        prop.find("input:visible:first").focus();

        setRevisionMessage(data.revision_message);
        deploy(data.inline_html);
        showCorrectButton();
      }
    });
  }

  // Submit einer Änderung an einem Daten-Property (oder Label)
  function updateProperty(form) {
    if (timeoutID != null) {
      window.clearTimeout(timeoutID);
      timeoutID = null;
    }

    var prop = form.closest(".property");
    var formGroup = form.children(".form-group");
    var input = formGroup.find("input, textarea, select");
    var value;
    if (input.attr("type") == "checkbox") {
      value = input.is(":checked") ? "true" : "false";
    } else {
      value = input.val(); // cache this for data-server-value field
    }
    var url = (prop.data("predicate") == "label") ? "/update/individual" : "/update/property"

    // Setze keine Request ab, wenn der Wert schon auf dem Server ist, oder man gerade
    // kurz vorher einen Request mit dem gleichen Wert gemacht hat.
    if (input.data("server-value") == value || input.data("pending-submission") == value) {
      return;
    }
    input.data("pending-submission", value);

    $.ajax({
      url: url,
      method: "PUT",
      dataType: "json",
      data: {
        value: value,
        id: prop.data("id"),
        // die nächsten beiden brauchen wir für "text, card:1, leer"
        predicate: prop.data("predicate"),
        individual_id: prop.data("individual-id"),
        revision_id: prop.data("revision-id"),
        inline_predicate: modal.data("predicate"),
        inline_individual_id: modal.data("individual-id")
      },
      success: function(data) {

        // TODO Validierung beachten

        input.data("pending-submission", null);
        input.data("server-value", value);
        // bei "text, card:1, leer"
        prop.data("id", data.id);
        prop.data("revision-id", data.revision_id);
        // TODO check if in der zwischenzeit keine Änderungen
        formGroup.removeClass("has-warning has-error").addClass("has-success");

        handleBaseProperty(data, prop.data("individual-id"));
        setRevisionMessage(data.revision_message);
        deploy(data.inline_html);

        if (data.visibility) {
          $(".glass-individual .concessions").find(".eye").hide();
          $(".glass-individual .concessions").find(".eye-" + data.visibility).show();
        }
      },
      error: function(data) {
        input.data("pending-submission", null);

        if (data.responseJSON) {
          if (data.responseJSON.errors) {
            setRevisionMessage(data.responseJSON.errors.join("<br>"));
          } else {
            setRevisionMessage("Die Änderungen konnten leider nicht gespeichert werden.");
          }
        } else if ($("body").data("rails-env") == "development") {
          setRevisionMessage("(Development): Turn off 'consider_all_links_local' to display error messages.")
        }

        formGroup.removeClass("has-success has-warning").addClass("has-error");
      }
    });
  }

  function deleteProperty(prop, successCallback) {
    var isLeftColumn = (prop.parents(".left-column").length > 0);
    var label = prop.find(".summary-span:first").text();
    var subjectId = prop.data("individual-id");

    if (!confirm("Sind sie sicher, dass " + label + " entfernt werden soll?")) {
      return;
    }

    $.ajax({
      url: "/update/property",
      method: "DELETE",
      dataType: "json",
      data: {
        id: prop.data("id"),
        inline_predicate: modal.data("predicate"),
        inline_individual_id: modal.data("individual-id")
      },
      success: function(data) {

        // TODO Validierung beachten?

        var objektId = prop.data("objekt-id");
        if  (objektId) {
          modal.find(".existing-individual[data-objekt-id=" + objektId + "]")
               .removeAttr("disabled");
        }

        // In Maya kein Ersetzen
        //// change icons if necessary
        //var createObjektPropertyForm = modal.find(".create-objekt-property");
        //if (createObjektPropertyForm.length != 0
        // && createObjektPropertyForm.hasClass("cardinality-one")) {
        //   createObjektPropertyForm
        //     .find(".glyphicon")
        //     .removeClass("glyphicon-retweet")
        //     .addClass("glyphicon-plus");
        //}

        if (isLeftColumn) {
          // Wenn wir in einem Zwei-Spalten-Model links sind, dann müssen wir den Add-Button
          // aktivieren und die rechte Spalte leeren, falls da noch Daten von dem gerade
          // gelöschten Property stehen.
          showCorrectButton();
          rightCol.empty();
        } else if (data.range) {
          // Wenn wir in der rechten Spalte und cardinality-one sind, dann wollen wir gleich die
          // Range einblenden.
          var range = $(data.range);
          range.find(".existing-individual").click(createObjektPropertyButtonClickHandler);
          var props = prop.closest(".properties").html(range);
        }

        prop.remove();

        handleBaseProperty(data, subjectId);
        // attach range input filter
        rightCol.find("input.range-filter").keyup(G.rangeFilterInputKeyUpHandler);
        setRevisionMessage(data.revision_message);
        deploy(data.inline_html);

        if (successCallback) {
          // Wird benutzt von dem Replace-Button, der sofort die Range anzeigt.
          successCallback();
        }
      },
      error: makeErrorAlerter("Property konnte nicht gelöscht werden")
    });
  }

  


  //
  // Helper functions
  //


  function updatePropertyInputKeyUpHandler(event) {
    var input = $(this);
    var formGroup = input.parent();
    if (input.val() != input.data("server-value")) { // we are dirty
      if (!formGroup.hasClass("has-warning")) { // but we say we are clean
        // TODO Nicht nur das Icon anzeigen, sondern irgendwo auch Text,
        // der erklärt, was gerade los ist.
        formGroup.removeClass("has-success has-error").addClass("has-warning");
      }

      if (timeoutID != null) {
        window.clearTimeout(timeoutID);
        timeoutID = null;
      }
      timeoutID = window.setTimeout(function() {
        formGroup.parent().submit();
      }, 500); // Speichern, wenn 500ms lang keine Eingaben
    }
  }


  function showCorrectButton() {
    var addBtn = modal.find(".add");
    var replaceBtn = modal.find(".replace");

    if (modal.data("cardinality-one") && leftCol.find(".property").length > 0) {
      addBtn.hide();
      replaceBtn.show();
    } else {
      addBtn.show();
      replaceBtn.hide();
    }
  }

  /**
    Zeigt im Footer eines Modals str an; falls ein focus_element gesetzt ist, dann
    wird die Nachricht ausgeblendet, sobald dieses Element den Fokus verliert.
  */
  function setRevisionMessage(str) {
    var div = modal.find(".revision-message");
    if (str.length > 90) {
      // Dies ist ein Workaround um sehr lange Revisionsnachrichten, wie sie bei
      // SciCollection#description vorkommen. Das ist natürlich keine richtige Lösung;
      // vielleicht allgemein auf die Anzeige der Revisionsnachrichten verzichten?
      str = "Die Änderungen wurden gespeichert.";
    }
    div.html(str).stop().css("opacity", 1).show();
  }

  function emptyRevisionMessage() {
    $(".revision-message").empty();
  }

	// Updatet die Seite im Hintergrund nachdem in einem Edit-Modal Änderungen
	// vorgenommen wurden.
	// inline_html - geupdatetes HTML für bearbeiteten Eintrag im individual-tab
	// relations_html - geupdatetes HTML für gesamten relations-tab
  function deploy(inline_html) {
    $(".tooltip").hide();
    var newPropertyGroup = $(inline_html).click(propertyGroupDivClickHandler).tooltip("enable");

    // TODO Make DRY (kommt schon in bindMainPageEvents vor).
    newPropertyGroup
      .find(".linker")
      .tooltip("enable")
      .mouseenter(function() { $(".tooltip:last").hide(); })
      .mouseleave(function() { $(".tooltip:last").show(); });

    var oldPropertyGroup = $(".glass-individual")
      .find(".property-group[data-predicate=" +
            modal.data("predicate") +
            "][data-individual-id=" +
            modal.data("individual-id") + "]");

    oldPropertyGroup.tooltip("hide");
    oldPropertyGroup.replaceWith(newPropertyGroup);
		
		if (typeof(attachInfoTooltip) == "function") {
			attachInfoTooltip(newPropertyGroup.find('.js-tooltip'));
		}
		
		$('.relations-tab').attr('refresh', true);

    clearRevisions();
  }

  // Für ein Property von einem weak Individual (zB URL von WebResource) bezeichne ich
  // das Property, das das weak Individual mit dem strong Individual verbindet, als
  // "Base-Property". Die folgende Methode kümmert sich um den Fall, dass sich etwas an dem
  // Base-Property ändert als Resultat davon, dass man das weak-Individual-Property ändert.
  // Zum Beispiel muss das Base-Property (das in der linken Spalte angezeigt wird) ausgeblendet
  // werden, wenn durch das leeren der URL das weak Individual nun ein leeres Label hätte.
  //
  // Diese Methode greift auf folgende Felder von data zu:
  // - data.base_property_removed (in diesem Fall entfernen)
  // - data.base_property (in diesem Fall hinzufügen)
  // - data.subject_label (in diesem Fall aktualisieren)
  function handleBaseProperty(data, objektId) {
    if (data.base_property_removed) {
      // Dies ist der Fall, dass das Subject gelöscht wurde.
      // In dem Fall den Eintrag in der linken Spalte entfernen.
      leftCol.find(".property[data-objekt-id=" + objektId + "]").remove();

      // Außerdem müssen wir alle Revision-Ids zurücksetzen, weil wir die alten Revisionen
      // nicht mehr verändern wollen.
      rightCol.find(".property").data("revision-id", null);

      // Die alten Individual-Ids können stehen bleiben, weil da im Controller dann
      // einfach nichts gefunden wird, und einer neuer weak Indi erstellt wird.
    } else if (data.base_property) {
      // Dies ist der Fall, dass das Subject (ein weak Individual) und das verbindende
      // Property (das "Base-Property") neu erstellt wurden.
      // Daher das Property-Html in der linken Spalte appenden.
      addPropertyToLeftColumn(data.base_property);

      // Und setze bei allen Properties und offenen Ranges des (weak) Individuals die Subject-Id
      // TODO "individual-id" zu "subject-id" umbenennen
      rightCol.find(".property, .create-objekt-property").data("individual-id", data.subject_id);
    } else if (data.subject_label) {
      // Andernfalls bloß das Label in der linken Spalte aktualisieren
      leftCol.find(".property[data-objekt-id=" + objektId + "] > .summary > .summary-span")
             .text(data.subject_label);
    }
    showCorrectButton();
  }

  function addPropertyToLeftColumn(html) {
    var prop = $(html);
    bindPropertyEvents(prop);
    modal.find(".selected").removeClass("selected");
    prop.find(".summary").addClass("selected");
    leftCol.find(".properties").append(prop);
  }

  function clearRevisions() {
    var tab = $(".glass-individual .revisions-tab");
    tab.find("#searchresults").empty();

    // Falls wir auf dem Revisions-Tab sind (möglich, wenn Label vom Individual
    // geändert wurde), dann wieder neue Revisions holen
    if (tab.is(":visible")) {
      G.fetchRevisions();
    }
  }


  // Eventuell Obsolet?

  // checks whether the data in the form would create a valid property (i.e. dry-run creation)
  // used to indicate validity of user input (e.g. green checkmark -> ok, red X -> invalid)
  function validateProperty(form) {
    var input = form.find("input");
    $.ajax({
      url: "/validate/property",
      method: "GET",
      data: {
        value: input.val(),
        predicate: form.data("predicate"),
        individual_id: form.data("individual-id"),
        inline_predicate: modal.data("predicate"),
        inline_individual_id: modal.data("individual-id")
      },
      success: function(data) {
        // TODO implement success indicator as when updating a property
        // formGroup.removeClass("has-warning has-error").addClass("has-success");
        var input = form.find("input");
        if (data.valid) {
          input.css('color', 'green');
          // enable submit button
          form.find("button[type='submit']").attr('disabled', false);
        }
        else {
          input.css('color', 'red');
          // disable submit button
          form.find("button[type='submit']").attr('disabled', true);
        }
        // add message notification
        setRevisionMessage(data.revision_message);
      }
    });
  }
})(Glass);