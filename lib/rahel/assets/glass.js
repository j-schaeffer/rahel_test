// glass.js
// Basis-Modul für Glass
// Anmerkung: Die Organisation des Glass-Moduls orientiert sich an diesem Pattern:
// http://molily.de/js/organisation-module.html#feste-kopplung

var Glass = (function() {
  // This object will be published, so all the public stuff goes in here.
  var G = {};

  G.submoduleInit = new Array();

  G.init = function() {
    bindMainPageEvents();

    // Die Init-Funktionen der Submodule ausführen
    for (var i = 0; i < G.submoduleInit.length; i++) {
      G.submoduleInit[i]();
    };
  };

  function bindMainPageEvents() {
    // Individual Tabs

    // React to Hash, which can change the default tab
    // nur wenn andere Tabs existieren (= User hat View-Rechte)
    if ($(location).attr("hash") == "#settings" && $(".glass-individual .settings-tab")[0]) {
      $(".glass-individual .individual-tab").hide();
      $(".glass-individual .relations-tab").hide();
      $(".glass-individual .revisions-tab").hide();
      $(".glass-individual .notes-tab").hide();
      $(".glass-individual .settings-tab").show();
    }

    if ($(location).attr("hash") == "#revisions" && $(".glass-individual .revisions-tab")[0]) {
      $(".glass-individual .individual-tab").hide();
      $(".glass-individual .relations-tab").hide();
      $(".glass-individual .settings-tab").hide();
      $(".glass-individual .notes-tab").hide();
      $(".glass-individual .revisions-tab").show();
      fetchRevisions();
    }
    
    if ($(location).attr("hash") == "#relations" && $(".glass-individual .relations-tab")[0]) {
      $(".glass-individual .individual-tab").hide();
      $(".glass-individual .revisions-tab").hide();
      $(".glass-individual .settings-tab").hide();
      $(".glass-individual .notes-tab").hide();
      $(".glass-individual .relations-tab").show();
      fetchRelations();
    }

    if ($(location).attr("hash") == "#notes" && $(".glass-individual .notes-tab")[0]) {
      $(".glass-individual .individual-tab").hide();
      $(".glass-individual .revisions-tab").hide();
      $(".glass-individual .settings-tab").hide();
      $(".glass-individual .relations-tab").hide();
      $(".glass-individual .notes-tab").show();
    }

    $(".show-default-tab").click(function(event) {
      window.location.hash = "";
      $(".glass-individual .individual-tab").hide();
      $(".glass-individual .relations-tab").hide();
      $(".glass-individual .notes-tab").hide();
      $(".glass-individual .default-tab").show();
      event.preventDefault();
    });

    $(".show-settings-tab").click(function(event) {
      window.location.hash = "settings";
      $(".glass-individual .individual-tab").hide();
      $(".glass-individual .relations-tab").hide();
      $(".glass-individual .notes-tab").hide();
      $(".glass-individual .settings-tab").show();
      event.preventDefault();
    });

    $(".show-revisions-tab").click(function(event) {
      window.location.hash = "revisions";
      $(".glass-individual .individual-tab").hide();
      $(".glass-individual .relations-tab").hide();
      $(".glass-individual .notes-tab").hide();
      $(".glass-individual .revisions-tab").show();
      fetchRevisions();
      event.preventDefault();
    });

    $(".show-relations-tab").click(function(event) {
      window.location.hash = "relations";
      $(".glass-individual .individual-tab").hide();
      $(".glass-individual .settings-tab").hide();
      $(".glass-individual .notes-tab").hide();
      $(".glass-individual .relations-tab").show();
      fetchRelations();
      event.preventDefault();
    });

    $(".show-notes-tab").click(function(event) {
      window.location.hash = "notes";
      $(".glass-individual .individual-tab").hide();
      $(".glass-individual .relations-tab").hide();
      $(".glass-individual .settings-tab").hide();
      $(".glass-individual .notes-tab").show();
      event.preventDefault();
    });


    // enable tooltips on external-link icons
    $(".glass-individual .linker").tooltip();
  }

  function fetchRevisions() {
    var tab = $(".glass-individual .revisions-tab");
    var resultsDiv = tab.find("#searchresults");
    if (resultsDiv.html() != "") {
      return;
    }

    if (NProgress != undefined) { NProgress.start(); }
    $.get("/revisions", { individual_id: tab.data("individual-id") }, function(html) {
      tab.find("#searchresults").replaceWith(html);
      if (NProgress != undefined) { NProgress.done(); }

      // Diese Funktion ist in search.js
      initJScroll();
    });
  }
  
  function fetchRelations() {
    var tab = $(".glass-individual .relations-tab");
    
    // check if something has changed; refresh == true is set by glass-edit:deploy()
    if (tab.attr('refresh') == undefined || tab.attr('refresh') == "true") {
      // display waiting animation
      tab.empty();

      if (NProgress != undefined) { NProgress.start(); }
      $.get("/relations", { id: tab.data("individual-id") }, function(html) {
        if (NProgress != undefined) { NProgress.done(); }
        tab.html(html);
      });
    }
  }


  //
  // API for submodules
  //

  G.fetchRevisions = fetchRevisions;

  G.bindModalEvents = function (modal) {
    // TODO geht noch nicht aus input/textarea heraus
    modal.on("keydown", function(e) {
      if (e.keyCode == 27) {
        // dismiss modal on Esc
        modal.modal("hide");
      }
    });

    modal.on("shown.bs.modal", function() {
      modal.find(".form-control:visible:first").focus();
    });

    // Entferne das Modal aus dem DOM, da sonst die Tabs verwirrt sind.
    modal.on("hidden.bs.modal", function () {
      // hide all tooltips
      $('.js-tooltip').qtip('hide');
      
      // in case an email-address was added to a Person:
      if ($(this).attr('data-predicate') == "email" && location.pathname.indexOf("Person") != -1) {
        // call reloadInviteStatus if defined (can be undefined since it is in maya)
        if (typeof reloadInviteStatus == "function") {
          reloadInviteStatus();
        // hard page reload otherwise
        } else {
          location.reload();
        }
      }
      
      // Entferne das Modal aus dem DOM, da sonst die Tabs verwirrt sind.
      modal.remove();
    });
  };

  G.rangeFilterInputKeyUpHandler = function() {
    var filterStr = $.trim($(this).val());
    var lowerFilterStr = filterStr.toLowerCase();
    var tokens = lowerFilterStr.split(" ");
    var toShow = [];
    var toHide = [];
    var directHits = [];
    var notDirectHits = [];
    //var typesWithExactMatches = [];
    G.modal.find(".range").children(".js-range-filter-target").each(function(index, btn) {
      var label = $(btn).text().toLowerCase();
      var labelAndRelated = $(btn).data("filter-text").toLowerCase();
      var allTokensMatchLabel = true;
      var allTokensMatchLabelAndRelated = true;
      $.each(tokens, function(i, token) {
        if (label.indexOf(token) == -1) {
          allTokensMatchLabel = false;
        }
        if (labelAndRelated.indexOf(token) == -1) {
          allTokensMatchLabelAndRelated = false;
        }
      });
      // Zeige einen Eintrag nur dann, wenn alle Tokens des Filter-Strings darin vorkommen.
      if (allTokensMatchLabelAndRelated) {
        toShow.push(btn);
        //if ($.trim(value) === lowerFilterStr) {
        //  typesWithExactMatches.push($(btn).data("type"));
        //}
      } else {
        toHide.push(btn);
      }
      // Hebe ihn hervor, wenn alle Tokens im Text vorkommen (aber nur, wenn wir in
      // Hierachie sind).
      if (btn.className.indexOf("level") > -1 && allTokensMatchLabel && filterStr.trim() != "") {
        directHits.push(btn);
      } else {
        notDirectHits.push(btn);
      }
    });
    $(toShow).show();
    $(toHide).hide();
    $(notDirectHits).removeClass("direct-hit");
    $(directHits).addClass("direct-hit");

    // Bei dem folgenden Auskommentierten geht es darum, anzubieten, direkt beim Filtern
    // einen neuen Individual zu erstellen, falls man keinen passenden in der Liste fand.
    // Das ging bei SAD, bei Maya jedoch nicht, deshalb ist es bis auf Weiteres auskommentiert.
    //// values auch noch durchgehen
    //modal.find(".existing-individual:disabled").each(function(i, btn) {
    //  var value = $.trim($(btn).text().toLowerCase());
    //  if ($.trim(value) === lowerFilterStr) {
    //    typesWithExactMatches.push($(btn).data("type"));
    //  }
    //});
    //
    //if (filterStr == "") {
    //  modal.find(".range").children(".new-individual").hide();
    //} else {
    //  modal.find("span#new-name").text(filterStr);
    //  modal.find(".range").children(".new-individual").each(function(i, node) {
    //    // "Neu"-Buttons anzeigen, aber nur solche, wo noch kein Individual mit dem selben
    //    // (case-insensitive) Label existiert.
    //    btn = $(node);
    //    if ($.inArray(btn.data("type"), typesWithExactMatches) == -1) {
    //      btn.show();
    //    } else {
    //      btn.hide();
    //    }
    //  });
    //}
  };

  return G;  
})();
