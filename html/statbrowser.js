// Polyfills and compatibility ------------------------------------------------
var decoder = decodeURIComponent || unescape;
if (!Array.prototype.includes) {
  Array.prototype.includes = function (thing) {
    for (var i = 0; i < this.length; i++) {
      if (this[i] == thing) return true;
    }
    return false;
  };
}
if (!String.prototype.trim) {
  String.prototype.trim = function () {
    return this.replace(/^[\s\uFEFF\xA0]+|[\s\uFEFF\xA0]+$/g, '');
  };
}

// Status panel implementation ------------------------------------------------
//status_tab_parts expects a list to be returned, to which we'll send a list within a list
//with just "loading" to not appear broken.
var status_tab_parts = [['Loading...']];
var current_tab = null;
//mc_tab_parts expects a list to be returned, to which we'll send a list within a list
//with just "loading" to not appear broken.
var mc_tab_parts = [['Loading...']];
var mc_tick_summary = {};
var mc_subsystems = [];
var mc_sort_mode = 'priority';
var mc_sort_descending = true;
var mc_hide_inactive = false;
var mc_name_query = '';
var mc_dashboard = null;
var mc_summary_usage = null;
var mc_summary_limit = null;
var mc_summary_internal = null;
var mc_summary_location = null;
var mc_summary_subsystem_usage = null;
var mc_summary_usage_window = null;
var mc_rolling_bar = null;
var mc_rolling_legend = null;
var mc_subsystem_count = null;
var mc_subsystem_list = null;
var mc_sort_select = null;
var mc_sort_direction = null;
var mc_inactive_button = null;
var mc_search_input = null;
var mc_expanded_details = {};
var href_token = null;
var verb_tabs = [];
var verbs = [['', '']]; // list with a list inside
var tickets = [];
var interviewManager = { status: '', interviews: [] };
var sdql2 = [];
var permanent_tabs = []; // tabs that won't be cleared by wipes
var turfcontents = [];
var turfname = '';
var imageRetryDelay = 500;
var imageRetryLimit = 50;
var menu = document.getElementById('menu');
var statcontentdiv = document.getElementById('statcontent');
var storedimages = [];
var split_admin_tabs = false;
//The 'default' tab that everyone should have, that we swap to if the tab you're on is deleted or anything similar.
var defaultTab = 'Status';

// Any BYOND commands that could result in the client's focus changing go through this
// to ensure that when we relinquish our focus, we don't do it after the result of
// a command has already taken focus for itself.
function run_after_focus(callback) {
  setTimeout(callback, 0);
}

function createStatusTab(name) {
  if (name.indexOf('.') != -1) {
    var splitName = name.split('.');
    if (split_admin_tabs && splitName[0] === 'Admin') name = splitName[1];
    else name = splitName[0];
  }
  if (document.getElementById(name) || name.trim() == '') {
    return;
  }
  if (!verb_tabs.includes(name) && !permanent_tabs.includes(name)) {
    return;
  }
  var button = document.createElement('DIV');
  button.onclick = function () {
    tab_change(name);
    this.blur();
    statcontentdiv.focus();
  };
  button.id = name;
  button.textContent = name;
  button.className = 'button';
  //ORDERING ALPHABETICALLY
  button.style.order = { Status: 1, MC: 2 }[name] || name.charCodeAt(0);
  //END ORDERING
  menu.appendChild(button);
  SendTabToByond(name);
}

function removeStatusTab(name) {
  if (!document.getElementById(name) || permanent_tabs.includes(name)) {
    return;
  }
  for (var i = verb_tabs.length - 1; i >= 0; --i) {
    if (verb_tabs[i] == name) {
      verb_tabs.splice(i, 1);
    }
  }
  menu.removeChild(document.getElementById(name));
  TakeTabFromByond(name);
}

function sortVerbs() {
  verbs.sort((a, b) => {
    var selector = a[0] == b[0] ? 1 : 0;
    if (a[selector].toUpperCase() < b[selector].toUpperCase()) {
      return 1;
    } else if (a[selector].toUpperCase() > b[selector].toUpperCase()) {
      return -1;
    }
    return 0;
  });
}

function addPermanentTab(name) {
  if (!permanent_tabs.includes(name)) {
    permanent_tabs.push(name);
  }
  createStatusTab(name);
}

function removePermanentTab(name) {
  for (var i = permanent_tabs.length - 1; i >= 0; --i) {
    if (permanent_tabs[i] == name) {
      permanent_tabs.splice(i, 1);
    }
  }
  removeStatusTab(name);
}

function checkStatusTab() {
  for (var i = 0; i < menu.children.length; i++) {
    if (
      !verb_tabs.includes(menu.children[i].id) &&
      !permanent_tabs.includes(menu.children[i].id)
    ) {
      menu.removeChild(menu.children[i]);
    }
  }
}

function remove_verb(v) {
  var verb_to_remove = v; // to_remove = [verb:category, verb:name]
  for (var i = verbs.length - 1; i >= 0; i--) {
    var part_to_remove = verbs[i];
    if (part_to_remove[1] == verb_to_remove[1]) {
      verbs.splice(i, 1);
    }
  }
}

function check_verbs() {
  for (var v = verb_tabs.length - 1; v >= 0; v--) {
    verbs_cat_check(verb_tabs[v]);
  }
}

function verbs_cat_check(cat) {
  var tabCat = cat;
  if (cat.indexOf('.') != -1) {
    var splitName = cat.split('.');
    if (split_admin_tabs && splitName[0] === 'Admin') tabCat = splitName[1];
    else tabCat = splitName[0];
  }
  var verbs_in_cat = 0;
  var verbcat = '';
  if (!verb_tabs.includes(tabCat)) {
    removeStatusTab(tabCat);
    return;
  }
  for (var v = 0; v < verbs.length; v++) {
    var part = verbs[v];
    verbcat = part[0];
    if (verbcat.indexOf('.') != -1) {
      var splitName = verbcat.split('.');
      if (split_admin_tabs && splitName[0] === 'Admin') verbcat = splitName[1];
      else verbcat = splitName[0];
    }
    if (verbcat != tabCat || verbcat.trim() == '') {
    } else {
      verbs_in_cat = 1;
      break; // we only need one
    }
  }
  if (verbs_in_cat != 1) {
    removeStatusTab(tabCat);
    if (current_tab == tabCat) tab_change(defaultTab);
  }
}

function findVerbindex(name, verblist) {
  for (var i = 0; i < verblist.length; i++) {
    var part = verblist[i];
    if (part[1] == name) return i;
  }
}
function wipe_verbs() {
  verbs = [['', '']];
  verb_tabs = [];
  checkStatusTab(); // remove all empty verb tabs
}

function update_verbs() {
  wipe_verbs();
  Byond.sendMessage('Update-Verbs');
}

function SendTabsToByond() {
  var tabstosend = [];
  tabstosend = tabstosend.concat(permanent_tabs, verb_tabs);
  for (var i = 0; i < tabstosend.length; i++) {
    SendTabToByond(tabstosend[i]);
  }
}

function SendTabToByond(tab) {
  Byond.sendMessage('Send-Tabs', { tab: tab });
}

//Byond can't have this tab anymore since we're removing it
function TakeTabFromByond(tab) {
  Byond.sendMessage('Remove-Tabs', { tab: tab });
}

function tab_change(tab) {
  if (tab == current_tab) return;
  if (document.getElementById(current_tab))
    document.getElementById(current_tab).className = 'button'; // disable active on last button
  current_tab = tab;
  set_byond_tab(tab);
  if (document.getElementById(tab))
    document.getElementById(tab).className = 'button active'; // make current button active
  var verb_tabs_thingy = verb_tabs.includes(tab);
  statcontentdiv.className = 'statcontent';
  if (tab == 'Status') {
    draw_status();
  } else if (tab == 'MC') {
    draw_mc();
  } else if (verb_tabs_thingy) {
    draw_verbs(tab);
  } else if (tab == 'Debug Stat Panel') {
    draw_debug();
  } else if (tab == 'Tickets') {
    draw_tickets();
    draw_interviews();
  } else if (tab == 'SDQL2') {
    draw_sdql2();
  } else if (tab == turfname) {
    draw_listedturf();
  } else {
    statcontentdiv.textContext = 'Loading...';
  }
  Byond.winset(Byond.windowId, {
    'is-visible': true,
  });
}

function set_byond_tab(tab) {
  Byond.sendMessage('Set-Tab', { tab: tab });
}

function draw_debug() {
  statcontentdiv.textContent = '';
  var wipeverbstabs = document.createElement('div');
  var link = document.createElement('a');
  link.onclick = () => {
    wipe_verbs();
  };
  link.textContent = 'Wipe All Verbs';
  wipeverbstabs.appendChild(link);
  document.getElementById('statcontent').appendChild(wipeverbstabs);
  var wipeUpdateVerbsTabs = document.createElement('div');
  var updateLink = document.createElement('a');
  updateLink.onclick = () => {
    update_verbs();
  };
  updateLink.textContent = 'Wipe and Update All Verbs';
  wipeUpdateVerbsTabs.appendChild(updateLink);
  document.getElementById('statcontent').appendChild(wipeUpdateVerbsTabs);
  var text = document.createElement('div');
  text.textContent = 'Verb Tabs:';
  document.getElementById('statcontent').appendChild(text);
  var table1 = document.createElement('table');
  for (var i = 0; i < verb_tabs.length; i++) {
    var part = verb_tabs[i];
    // Hide subgroups except admin subgroups if they are split
    if (verb_tabs[i].lastIndexOf('.') != -1) {
      var splitName = verb_tabs[i].split('.');
      if (split_admin_tabs && splitName[0] === 'Admin') part = splitName[1];
      else continue;
    }
    var tr = document.createElement('tr');
    var td1 = document.createElement('td');
    td1.textContent = part;
    var a = document.createElement('a');
    a.onclick = ((part) => () => {
      removeStatusTab(part);
    })(part);
    a.textContent = ' Delete Tab ' + part;
    td1.appendChild(a);
    tr.appendChild(td1);
    table1.appendChild(tr);
  }
  document.getElementById('statcontent').appendChild(table1);
  var header2 = document.createElement('div');
  header2.textContent = 'Verbs:';
  document.getElementById('statcontent').appendChild(header2);
  var table2 = document.createElement('table');
  for (var v = 0; v < verbs.length; v++) {
    var part2 = verbs[v];
    var trr = document.createElement('tr');
    var tdd1 = document.createElement('td');
    tdd1.textContent = part2[0];
    var tdd2 = document.createElement('td');
    tdd2.textContent = part2[1];
    trr.appendChild(tdd1);
    trr.appendChild(tdd2);
    table2.appendChild(trr);
  }
  document.getElementById('statcontent').appendChild(table2);
  var text3 = document.createElement('div');
  text3.textContent = 'Permanent Tabs:';
  document.getElementById('statcontent').appendChild(text3);
  var table3 = document.createElement('table');
  for (var i = 0; i < permanent_tabs.length; i++) {
    var part3 = permanent_tabs[i];
    var trrr = document.createElement('tr');
    var tddd1 = document.createElement('td');
    tddd1.textContent = part3;
    trrr.appendChild(tddd1);
    table3.appendChild(trrr);
  }
  document.getElementById('statcontent').appendChild(table3);
}

function draw_status() {
  if (!document.getElementById('Status')) {
    createStatusTab('Status');
    current_tab = 'Status';
  }
  statcontentdiv.textContent = '';
  let lastdiv;
  const table = document.createElement('table');
  for (let i = 0; i < status_tab_parts.length; i++) {
    const part = status_tab_parts[i];
    // status tab elements can be a simple string, or an array with instructions
    if (!Array.isArray(part)) {
      // if it's a string, just make a div and slap the text in it
      const div = document.createElement('div');
      lastdiv = div;
      if (part.trim() === '') {
        table.appendChild(document.createElement('br'));
      } else {
        div.textContent = part;
        table.appendChild(div);
      }
      continue;
    }

    // complex handling needed
    let div;
    const base = part[0].trim();
    // 'same_line' = append the following content to the last div created
    // as a link, rather than creating a new div
    if (base === 'same_line') {
      const a = document.createElement('a');
      a.href = 'byond://?' + part[2];
      a.textContent = part[1];
      lastdiv.appendChild(a);
    } else {
      div = document.createElement('div');
      lastdiv = div;
    }

    // '' = newline
    if (base === '') {
      table.appendChild(document.createElement('br'));
      // 'img' = display an image with optional caption
    } else if (base === 'img') {
      if (part.length > 3) {
        const img_with_caption_table = document.createElement('table');
        const mainrow = document.createElement('tr');
        const img = document.createElement('img');
        img.src = part[1];
        img.alt = part[2];
        img.title = part[2];
        const img_td = document.createElement('td');
        img_td.appendChild(img);
        mainrow.appendChild(img_td);
        const caption_td = document.createElement('td');
        caption_td.textContent = part[3];
        caption_td.title = part.length > 4 ? part[4] : '';
        mainrow.appendChild(caption_td);
        img_with_caption_table.appendChild(mainrow);
        table.appendChild(img_with_caption_table);
      } else {
        const img = document.createElement('img');
        img.src = part[1];
        img.alt = part[2];
        div.appendChild(img);
        table.appendChild(div);
      }
      // default = interpret it as a link
    } else {
      div.textContent = base;
      if (part[2]) {
        const a = document.createElement('a');
        a.href = 'byond://?' + part[2];
        a.textContent = part[1];
        div.appendChild(a);
      }
      table.appendChild(div);
    }
  }
  document.getElementById('statcontent').appendChild(table);
  if (verb_tabs.length == 0 || !verbs) {
    Byond.command('Fix-Stat-Panel');
  }
}

function draw_mc() {
  statcontentdiv.className = "mcstatcontent";
  if (!mc_dashboard || !statcontentdiv.contains(mc_dashboard)) {
    statcontentdiv.textContent = "";
    mc_dashboard = document.createElement("div");
    mc_dashboard.className = "mc-dashboard";

    var heading = document.createElement("div");
    heading.className = "mc-heading";
    var title = document.createElement("strong");
    title.textContent = "MC / Subsystems";
    mc_summary_location = document.createElement("span");
    mc_summary_location.className = "mc-location";
    heading.appendChild(title);
    heading.appendChild(mc_summary_location);
    mc_dashboard.appendChild(heading);

    var overview = document.createElement("div");
    overview.className = "mc-overview";
    var usageCard = document.createElement("div");
    usageCard.className = "mc-usage-card";
    var usageTitle = document.createElement("div");
    usageTitle.className = "mc-card-title";
    usageTitle.textContent = "Current tick usage";
    mc_summary_usage = document.createElement("strong");
    mc_summary_usage.className = "mc-usage-value";
    mc_summary_limit = document.createElement("span");
    mc_summary_limit.className = "mc-limit-value";
    var gauge = document.createElement("div");
    gauge.className = "mc-gauge";
    gauge.setAttribute("role", "img");
    gauge.setAttribute(
      "aria-label",
      "Current tick usage, MC threshold, and normal running limit",
    );
    var gaugeTrack = document.createElement("div");
    gaugeTrack.className = "mc-gauge-track";
    var gaugeFill = document.createElement("div");
    gaugeFill.className = "mc-gauge-fill";
    gaugeFill.id = "mc-gauge-fill";
    var mcMarker = document.createElement("div");
    mcMarker.className = "mc-gauge-marker mc-gauge-mc-marker";
    mcMarker.title = "MC queue scheduling threshold";
    var limitMarker = document.createElement("div");
    limitMarker.className = "mc-gauge-marker mc-gauge-limit-marker";
    limitMarker.title = "Normal running limit";
    gaugeTrack.appendChild(gaugeFill);
    gaugeTrack.appendChild(mcMarker);
    gaugeTrack.appendChild(limitMarker);
    gauge.appendChild(gaugeTrack);
    var gaugeLegend = document.createElement("div");
    gaugeLegend.className = "mc-gauge-legend";
    gaugeLegend.textContent = "MC threshold 70% | normal running limit";
    var internals = document.createElement("div");
    internals.className = "mc-internal-usage";
    internals.appendChild(
      document.createTextNode("BYOND internal usage (previous tick): "),
    );
    mc_summary_internal = document.createElement("strong");
    internals.appendChild(mc_summary_internal);
    usageCard.appendChild(usageTitle);
    usageCard.appendChild(mc_summary_usage);
    usageCard.appendChild(gauge);
    usageCard.appendChild(mc_summary_limit);
    usageCard.appendChild(gaugeLegend);
    usageCard.appendChild(internals);
    overview.appendChild(usageCard);

    var rollingCard = document.createElement("div");
    rollingCard.className = "mc-rolling-card";
    var rollingTitle = document.createElement("div");
    rollingTitle.className = "mc-card-title";
    rollingTitle.textContent = "Subsystem usage per tick";
    mc_summary_subsystem_usage = document.createElement("strong");
    mc_summary_subsystem_usage.className =
      "mc-summary-subsystem-usage mc-usage-value";
    mc_summary_usage_window = document.createElement("span");
    mc_summary_usage_window.className = "mc-limit-value";
    mc_rolling_bar = document.createElement("div");
    mc_rolling_bar.className = "mc-stacked-bar";
    mc_rolling_bar.setAttribute("role", "img");
    mc_rolling_bar.setAttribute(
      "aria-label",
      "Subsystem contributions to tick usage over a rolling window",
    );
    mc_rolling_legend = document.createElement("div");
    mc_rolling_legend.className = "mc-rolling-legend";
    rollingCard.appendChild(rollingTitle);
    rollingCard.appendChild(mc_summary_subsystem_usage);
    rollingCard.appendChild(mc_summary_usage_window);
    rollingCard.appendChild(mc_rolling_bar);
    rollingCard.appendChild(mc_rolling_legend);
    overview.appendChild(rollingCard);
    mc_dashboard.appendChild(overview);

    var controllerDetails = document.createElement("details");
    controllerDetails.className = "mc-controller-details";
    var detailsSummary = document.createElement("summary");
    detailsSummary.textContent = "Controller and world details";
    controllerDetails.appendChild(detailsSummary);
    var detailsTable = document.createElement("table");
    detailsTable.className = "mc-details-table";
    controllerDetails.appendChild(detailsTable);
    mc_dashboard.appendChild(controllerDetails);

    var toolbar = document.createElement("div");
    toolbar.className = "mc-toolbar";
    var listTitle = document.createElement("strong");
    listTitle.textContent = "Subsystems";
    mc_subsystem_count = document.createElement("span");
    mc_subsystem_count.className = "mc-subsystem-count";
    var searchLabel = document.createElement("label");
    searchLabel.className = "mc-search-label";
    searchLabel.textContent = "Search";
    mc_search_input = document.createElement("input");
    mc_search_input.type = "search";
    mc_search_input.className = "mc-search";
    mc_search_input.placeholder = "Subsystem name";
    mc_search_input.value = mc_name_query;
    mc_search_input.oninput = function () {
      mc_name_query = mc_search_input.value;
      render_mc_subsystems();
    };
    searchLabel.appendChild(mc_search_input);
    mc_sort_select = document.createElement("select");
    mc_sort_select.className = "mc-sort-select";
    var sortModes = [
      ["priority", "Run order / priority"],
      ["usage_per_tick", "Usage per tick"],
      ["usage", "Usage per run"],
      ["allocation", "Allowance per slice"],
      ["cost", "Cost per fire"],
      ["name", "Name"],
    ];
    for (var sortIndex = 0; sortIndex < sortModes.length; sortIndex++) {
      var sortOption = document.createElement("option");
      sortOption.value = sortModes[sortIndex][0];
      sortOption.textContent = sortModes[sortIndex][1];
      mc_sort_select.appendChild(sortOption);
    }
    mc_sort_select.value = mc_sort_mode;
    mc_sort_select.onchange = function () {
      mc_sort_mode = mc_sort_select.value;
      mc_sort_descending = mc_sort_mode !== "name";
      render_mc_subsystems();
    };
    mc_sort_direction = document.createElement("button");
    mc_sort_direction.className = "mc-control-button";
    mc_sort_direction.onclick = function () {
      mc_sort_descending = !mc_sort_descending;
      render_mc_subsystems();
    };
    mc_inactive_button = document.createElement("button");
    mc_inactive_button.className = "mc-control-button";
    mc_inactive_button.onclick = function () {
      mc_hide_inactive = !mc_hide_inactive;
      render_mc_subsystems();
    };
    toolbar.appendChild(listTitle);
    toolbar.appendChild(mc_subsystem_count);
    toolbar.appendChild(searchLabel);
    toolbar.appendChild(mc_sort_select);
    toolbar.appendChild(mc_sort_direction);
    toolbar.appendChild(mc_inactive_button);
    mc_dashboard.appendChild(toolbar);

    var columns = document.createElement("div");
    columns.className = "mc-list-columns";
    columns.innerHTML =
      "<span>Subsystem</span><span>Priority</span><span>Avg allowance / slice</span><span>Usage / run</span><span>Usage / tick</span><span>Cost</span><span></span>";
    mc_dashboard.appendChild(columns);
    mc_subsystem_list = document.createElement("div");
    mc_subsystem_list.className = "mc-subsystem-list";
    mc_dashboard.appendChild(mc_subsystem_list);
    statcontentdiv.appendChild(mc_dashboard);
  }

  render_mc_summary();
  render_mc_rolling_summary();
  render_mc_details();
  render_mc_subsystems();
}

function mc_number(value, digits) {
  var number = Number(value);
  if (!isFinite(number)) number = 0;
  return number.toFixed(digits);
}

function mc_clamp_percent(value) {
  return Math.max(0, Math.min(100, Number(value) || 0));
}

function render_mc_summary() {
  mc_summary_location.textContent =
    "Location: " + (mc_tick_summary.coord_entry || "Unknown");
  var usage = Number(mc_tick_summary.tick_usage) || 0;
  var runningLimit = Number(mc_tick_summary.running_limit) || 0;
  var mcLimit = Number(mc_tick_summary.mc_limit) || 70;
  var fill = document.getElementById("mc-gauge-fill");
  mc_summary_usage.textContent = mc_number(usage, 1) + "%";
  mc_summary_limit.textContent =
    "Normal running limit: " + mc_number(runningLimit, 1) + "%";
  mc_summary_internal.textContent = mc_number(mc_tick_summary.map_cpu, 1) + "%";
  fill.style.width = mc_clamp_percent(usage) + "%";
  fill.className =
    "mc-gauge-fill" +
    (usage >= runningLimit
      ? " mc-gauge-over-limit"
      : usage >= mcLimit
        ? " mc-gauge-near-limit"
        : "");
  var markers = mc_dashboard.querySelectorAll(".mc-gauge-marker");
  markers[0].style.left = mc_clamp_percent(mcLimit) + "%";
  markers[0].title =
    "MC queue scheduling threshold: " + mc_number(mcLimit, 1) + "%";
  markers[1].style.left = mc_clamp_percent(runningLimit) + "%";
  markers[1].title =
    "Normal running limit: " + mc_number(runningLimit, 1) + "%";
}

function render_mc_rolling_summary() {
  var total = Number(mc_tick_summary.subsystem_usage_per_tick) || 0;
  var windowSeconds = Number(mc_tick_summary.usage_window_seconds) || 0;
  mc_summary_subsystem_usage.textContent = mc_number(total, 1) + "% / tick";
  mc_summary_usage_window.textContent =
    mc_number(windowSeconds, 1) + "s rolling window";
  mc_rolling_bar.textContent = "";
  mc_rolling_legend.textContent = "";
  mc_rolling_bar.className =
    "mc-stacked-bar" + (total > 100 ? " mc-stacked-bar-over-cap" : "");
  mc_rolling_bar.setAttribute(
    "aria-label",
    "Subsystems use " + mc_number(total, 1) + "% of a tick on average over " +
      mc_number(windowSeconds, 1) + " seconds",
  );

  var consumers = mc_subsystems
    .filter(function (subsystem) {
      return Number(subsystem.usage_per_tick) > 0;
    })
    .sort(function (a, b) {
      return Number(b.usage_per_tick) - Number(a.usage_per_tick);
    });
  var shownUsage = 0;
  var topCount = Math.min(5, consumers.length);
  for (var i = 0; i < topCount; i++) {
    var subsystem = consumers[i];
    var value = Number(subsystem.usage_per_tick) || 0;
    shownUsage += value;
    append_mc_rolling_segment(
      subsystem.name,
      value,
      "mc-segment-" + (i % 5),
    );
  }
  var otherSubsystemUsage = Math.max(0, total - shownUsage);
  if (otherSubsystemUsage > 0.01) {
    append_mc_rolling_segment(
      "Other subsystems",
      otherSubsystemUsage,
      "mc-segment-other",
    );
  }
  var unaccounted = Math.max(0, 100 - total);
  if (unaccounted > 0.01) {
    append_mc_rolling_segment(
      "Other tick use / idle",
      unaccounted,
      "mc-segment-unaccounted",
    );
  }
  if (!mc_tick_summary.usage_collection_active) {
    var inactive = document.createElement("span");
    inactive.className = "mc-rolling-status";
    inactive.textContent = "Rolling collection is inactive";
    mc_rolling_legend.appendChild(inactive);
  }
}

function append_mc_rolling_segment(label, value, colorClass) {
  var segment = document.createElement("div");
  segment.className = "mc-stacked-segment " + colorClass;
  segment.style.width = mc_clamp_percent(value) + "%";
  segment.title = label + ": " + mc_number(value, 2) + "% per tick";
  mc_rolling_bar.appendChild(segment);

  var legendItem = document.createElement("span");
  legendItem.className = "mc-legend-item";
  legendItem.title = segment.title;
  var swatch = document.createElement("span");
  swatch.className = "mc-legend-swatch " + colorClass;
  var legendText = document.createElement("span");
  legendText.textContent = label + " " + mc_number(value, 1) + "%";
  legendItem.appendChild(swatch);
  legendItem.appendChild(legendText);
  mc_rolling_legend.appendChild(legendItem);
}

function render_mc_details() {
  var table = mc_dashboard.querySelector(".mc-details-table");
  table.textContent = "";
  for (var i = 0; i < mc_tab_parts.length; i++) {
    var part = mc_tab_parts[i];
    var row = document.createElement("tr");
    var label = document.createElement("th");
    label.textContent = part[1] || "";
    var value = document.createElement("td");
    if (part[3]) {
      var link = document.createElement("a");
      link.href =
        "byond://?_src_=vars;admin_token=" + href_token + ";Vars=" + part[3];
      link.textContent = part[2];
      value.appendChild(link);
    } else {
      value.textContent = part[2] || "";
    }
    row.appendChild(label);
    row.appendChild(value);
    table.appendChild(row);
  }
}

function mc_scheduler_group(subsystem) {
  if (mc_is_inactive(subsystem)) return 3;
  if (subsystem.background) return 2;
  if (subsystem.ticker) return 0;
  return 1;
}

function mc_is_inactive(subsystem) {
  return !subsystem.initialized || subsystem.doesnt_fire || !subsystem.can_fire;
}

function render_mc_subsystems() {
  if (!mc_subsystem_list) return;
  var query = mc_name_query.toLowerCase();
  var filtered = mc_subsystems.filter(function (subsystem) {
    return (
      (!mc_hide_inactive || !mc_is_inactive(subsystem)) &&
      (!query || subsystem.name.toLowerCase().indexOf(query) !== -1)
    );
  });
  filtered.sort(function (a, b) {
    var result = 0;
    if (mc_sort_mode === "priority") {
      result = mc_scheduler_group(a) - mc_scheduler_group(b);
      if (!result) result = Number(b.priority) - Number(a.priority);
      if (
        !result &&
        mc_sort_descending === false &&
        mc_scheduler_group(a) === mc_scheduler_group(b)
      ) {
        result = Number(a.priority) - Number(b.priority);
      }
    } else if (mc_sort_mode !== "name") {
      result = Number(a[mc_sort_mode]) - Number(b[mc_sort_mode]);
      if (mc_sort_descending) result *= -1;
      if (!result) result = mc_scheduler_group(a) - mc_scheduler_group(b);
      if (!result) result = Number(b.priority) - Number(a.priority);
    }
    if (result && mc_sort_mode === "priority") return result;
    if (mc_sort_mode === "name") {
      result =
        a.name.toLowerCase() < b.name.toLowerCase()
          ? -1
          : a.name.toLowerCase() > b.name.toLowerCase()
            ? 1
            : 0;
      if (mc_sort_descending) result *= -1;
    }
    if (!result && mc_sort_mode !== "name") {
      result =
        a.name.toLowerCase() < b.name.toLowerCase()
          ? -1
          : a.name.toLowerCase() > b.name.toLowerCase()
            ? 1
            : 0;
    }
    return result;
  });
  mc_subsystem_count.textContent =
    "(" + filtered.length + " / " + mc_subsystems.length + ")";
  mc_sort_direction.textContent = mc_sort_descending
    ? "Descending"
    : "Ascending";
  mc_sort_direction.setAttribute("aria-label", mc_sort_direction.textContent);
  mc_inactive_button.textContent = mc_hide_inactive
    ? "Show inactive"
    : "Hide inactive";
  mc_inactive_button.className =
    "mc-control-button" + (mc_hide_inactive ? " selected" : "");

  mc_subsystem_list.textContent = "";
  for (var i = 0; i < filtered.length; i++) {
    mc_subsystem_list.appendChild(create_mc_subsystem_row(filtered[i]));
  }
}

function create_mc_bar(label, value, unit) {
  var field = document.createElement("div");
  field.className = "mc-row-field";
  var head = document.createElement("div");
  head.className = "mc-row-field-head";
  var fieldLabel = document.createElement("span");
  fieldLabel.className = "mc-mobile-label";
  fieldLabel.textContent = label;
  var number = Number(value) || 0;
  var fieldValue = document.createElement("strong");
  fieldValue.textContent = mc_number(number, 2) + unit;
  head.appendChild(fieldLabel);
  head.appendChild(fieldValue);
  var track = document.createElement("div");
  track.className = "mc-row-bar";
  var fill = document.createElement("div");
  fill.className =
    "mc-row-bar-fill" +
    (number >= 25
      ? " mc-row-bar-high"
      : number >= 10
        ? " mc-row-bar-medium"
        : "");
  fill.style.width = mc_clamp_percent(number) + "%";
  track.appendChild(fill);
  field.appendChild(head);
  field.appendChild(track);
  return field;
}

function create_mc_subsystem_row(subsystem) {
  var row = document.createElement("div");
  row.className = "mc-row";
  var stateName = subsystem.state || " ";
  var stateLabel =
    stateName === "R"
      ? "Running"
      : stateName === "Q"
        ? "Queued"
        : stateName === "P"
          ? "Paused"
          : stateName === "S"
            ? "Sleeping"
            : "Idle";
  var stateClass = "mc-state-idle";
  if (!subsystem.initialized) {
    stateLabel = "Not initialized";
    stateClass = "mc-state-offline";
  } else if (subsystem.doesnt_fire) {
    stateLabel = "Does not fire";
    stateClass = "mc-state-offline";
  } else if (!subsystem.can_fire) {
    stateLabel = "Disabled";
    stateClass = "mc-state-offline";
  } else if (stateName === "R") {
    stateClass = "mc-state-running";
  } else if (stateName === "Q" || stateName === "P") {
    stateClass = "mc-state-queued";
  }

  var name = document.createElement("div");
  name.className = "mc-row-name";
  var state = document.createElement("span");
  state.className = "mc-state " + stateClass;
  state.textContent = stateName.trim() || "-";
  state.title = stateLabel;
  var nameText = document.createElement("strong");
  nameText.textContent = subsystem.name;
  var group = document.createElement("span");
  group.className = "mc-group-badge";
  group.textContent = subsystem.background
    ? "BACKGROUND"
    : subsystem.ticker
      ? "TICKER"
      : "REGULAR";
  name.appendChild(state);
  name.appendChild(nameText);
  name.appendChild(group);

  var priority = document.createElement("div");
  priority.className = "mc-row-priority";
  var priorityLabel = document.createElement("span");
  priorityLabel.className = "mc-mobile-label";
  priorityLabel.textContent = "Priority";
  var priorityValue = document.createElement("strong");
  priorityValue.textContent = subsystem.priority;
  priority.appendChild(priorityLabel);
  priority.appendChild(priorityValue);

  var allocation = create_mc_bar(
    "Allowance / slice",
    subsystem.allocation,
    "%",
  );
  allocation.className += " mc-allocation-field";
  allocation.title =
    "Average tick budget granted at the start of each execution slice, including resumed slices";
  var usage = create_mc_bar("Usage / run", subsystem.usage, "%");
  usage.className += " mc-usage-field";
  usage.title =
    "Average tick usage for a completed subsystem run, including resumed slices";
  var usagePerTick = create_mc_bar(
    "Usage / tick",
    subsystem.usage_per_tick,
    "%",
  );
  usagePerTick.className += " mc-usage-per-tick-field";
  usagePerTick.title = "Average tick usage per world tick over the rolling window";

  var cost = document.createElement("div");
  cost.className = "mc-row-cost";
  var costLabel = document.createElement("span");
  costLabel.className = "mc-mobile-label";
  costLabel.textContent = "Cost";
  var costValue = document.createElement("strong");
  costValue.textContent = mc_number(subsystem.cost, 2) + " ms";
  cost.appendChild(costLabel);
  cost.appendChild(costValue);

  var actions = document.createElement("div");
  actions.className = "mc-row-actions";
  if (subsystem.ref && href_token) {
    var vv = document.createElement("a");
    vv.className = "mc-vv-button";
    vv.href =
      "byond://?_src_=vars;admin_token=" +
      href_token +
      ";Vars=" +
      subsystem.ref;
    vv.textContent = "VV";
    vv.title = "View Variables";
    vv.setAttribute("aria-label", "View Variables for " + subsystem.name);
    actions.appendChild(vv);
  }

  var details = document.createElement("details");
  details.className = "mc-row-details";
  details.open = !!mc_expanded_details[subsystem.name];
  details.ontoggle = function () {
    mc_expanded_details[subsystem.name] = details.open;
  };
  var detailSummary = document.createElement("summary");
  detailSummary.textContent = "Details";
  var detailText = document.createElement("span");
  detailText.textContent = subsystem.stat_entry || "";
  details.appendChild(detailSummary);
  details.appendChild(detailText);
  if (Number(subsystem.overrun) > 0) {
    var overrun = document.createElement("span");
    overrun.className = "mc-overrun";
    overrun.textContent = "Overrun: " + mc_number(subsystem.overrun, 2) + "%";
    details.appendChild(overrun);
  }

  row.appendChild(name);
  row.appendChild(priority);
  row.appendChild(allocation);
  row.appendChild(usage);
  row.appendChild(usagePerTick);
  row.appendChild(cost);
  row.appendChild(actions);
  row.appendChild(details);
  return row;
}

function remove_tickets() {
  if (tickets) {
    tickets = [];
    removePermanentTab('Tickets');
    if (current_tab == 'Tickets') tab_change(defaultTab);
  }
  checkStatusTab();
}

function remove_sdql2() {
  if (sdql2) {
    sdql2 = [];
    removePermanentTab('SDQL2');
    if (current_tab == 'SDQL2') tab_change(defaultTab);
  }
  checkStatusTab();
}

function remove_interviews() {
  if (tickets) {
    tickets = [];
  }
  checkStatusTab();
}

function iconError(e) {
  if (current_tab != turfname) {
    return;
  }
  setTimeout(() => {
    var node = e.target;
    var current_attempts = Number(node.getAttribute('data-attempts')) || 0;
    if (current_attempts > imageRetryLimit) {
      return;
    }
    var src = node.src;
    node.src = null;
    node.src = src + '#' + current_attempts;
    node.setAttribute('data-attempts', current_attempts + 1);
    draw_listedturf();
  }, imageRetryDelay);
}

function draw_listedturf() {
  statcontentdiv.textContent = '';
  var table = document.createElement('table');
  for (var i = 0; i < turfcontents.length; i++) {
    var part = turfcontents[i];
    var clickfunc = ((part) => {
      // The outer function is used to close over a fresh "part" variable,
      // rather than every onmousedown getting the "part" of the last entry.
      return (e) => {
        e.preventDefault();
        clickcatcher = 'byond://?src=' + part[1];
        switch (e.button) {
          case 1:
            clickcatcher += ';statpanel_item_click=middle';
            break;
          case 2:
            clickcatcher += ';statpanel_item_click=right';
            break;
          default:
            clickcatcher += ';statpanel_item_click=left';
        }
        if (e.shiftKey) {
          clickcatcher += ';statpanel_item_shiftclick=1';
        }
        if (e.ctrlKey) {
          clickcatcher += ';statpanel_item_ctrlclick=1';
        }
        if (e.altKey) {
          clickcatcher += ';statpanel_item_altclick=1';
        }
        window.location.href = clickcatcher;
      };
    })(part);
    if (storedimages[part[1]] == null && part[2]) {
      var img = document.createElement('img');
      img.src = part[2];
      img.id = part[1];
      storedimages[part[1]] = part[2];
      img.onerror = iconError;
      img.onmousedown = clickfunc;
      table.appendChild(img);
    } else {
      var img = document.createElement('img');
      img.onerror = iconError;
      img.onmousedown = clickfunc;
      img.src = storedimages[part[1]];
      img.id = part[1];
      table.appendChild(img);
    }
    var b = document.createElement('div');
    var clickcatcher = '';
    b.className = 'link';
    b.onmousedown = clickfunc;
    b.textContent = part[0];
    table.appendChild(b);
    table.appendChild(document.createElement('br'));
  }
  document.getElementById('statcontent').appendChild(table);
}

function remove_listedturf() {
  removePermanentTab(turfname);
  checkStatusTab();
  if (current_tab == turfname) {
    tab_change(defaultTab);
  }
}

function remove_mc() {
  removePermanentTab('MC');
  if (current_tab == 'MC') {
    tab_change(defaultTab);
  }
}

function draw_sdql2() {
  statcontentdiv.textContent = '';
  var table = document.createElement('table');
  for (var i = 0; i < sdql2.length; i++) {
    var part = sdql2[i];
    var tr = document.createElement('tr');
    var td1 = document.createElement('td');
    td1.textContent = part[0];
    var td2 = document.createElement('td');
    if (part[2]) {
      var a = document.createElement('a');
      a.href = 'byond://?src=' + part[2] + ';statpanel_item_click=left';
      a.textContent = part[1];
      td2.appendChild(a);
    } else {
      td2.textContent = part[1];
    }
    tr.appendChild(td1);
    tr.appendChild(td2);
    table.appendChild(tr);
  }
  document.getElementById('statcontent').appendChild(table);
}

function draw_tickets() {
  statcontentdiv.textContent = '';
  var table = document.createElement('table');
  if (!tickets) {
    return;
  }
  for (var i = 0; i < tickets.length; i++) {
    var part = tickets[i];
    var tr = document.createElement('tr');
    var td1 = document.createElement('td');
    td1.textContent = part[0];
    var td2 = document.createElement('td');
    if (part[2]) {
      var a = document.createElement('a');
      a.href =
        'byond://?_src_=holder;admin_token=' +
        href_token +
        ';ahelp=' +
        part[2] +
        ';ahelp_action=ticket;statpanel_item_click=left;action=ticket';
      a.textContent = part[1];
      td2.appendChild(a);
    } else if (part[3]) {
      var a = document.createElement('a');
      a.href = 'byond://?src=' + part[3] + ';statpanel_item_click=left';
      a.textContent = part[1];
      td2.appendChild(a);
    } else {
      td2.textContent = part[1];
    }
    tr.appendChild(td1);
    tr.appendChild(td2);
    table.appendChild(tr);
  }
  document.getElementById('statcontent').appendChild(table);
}

function draw_interviews() {
  var body = document.createElement('div');
  var header = document.createElement('h3');
  header.textContent = 'Interviews';
  body.appendChild(header);
  var manDiv = document.createElement('div');
  manDiv.className = 'interview_panel_controls';
  var manLink = document.createElement('a');
  manLink.textContent = 'Open Interview Manager Panel';
  manLink.href =
    'byond://?_src_=holder;admin_token=' +
    href_token +
    ';interview_man=1;statpanel_item_click=left';
  manDiv.appendChild(manLink);
  body.appendChild(manDiv);

  // List interview stats
  var statsDiv = document.createElement('table');
  statsDiv.className = 'interview_panel_stats';
  for (var key in interviewManager.status) {
    var d = document.createElement('div');
    var tr = document.createElement('tr');
    var stat_name = document.createElement('td');
    var stat_text = document.createElement('td');
    stat_name.textContent = key;
    stat_text.textContent = interviewManager.status[key];
    tr.appendChild(stat_name);
    tr.appendChild(stat_text);
    statsDiv.appendChild(tr);
  }
  body.appendChild(statsDiv);
  document.getElementById('statcontent').appendChild(body);

  // List interviews if any are open
  var table = document.createElement('table');
  table.className = 'interview_panel_table';
  if (!interviewManager) {
    return;
  }
  for (var i = 0; i < interviewManager.interviews.length; i++) {
    var part = interviewManager.interviews[i];
    var tr = document.createElement('tr');
    var td = document.createElement('td');
    var a = document.createElement('a');
    a.textContent = part['status'];
    a.href =
      'byond://?_src_=holder;admin_token=' +
      href_token +
      ';interview=' +
      part['ref'] +
      ';statpanel_item_click=left';
    td.appendChild(a);
    tr.appendChild(td);
    table.appendChild(tr);
  }
  document.getElementById('statcontent').appendChild(table);
}

function make_verb_onclick(command) {
  return () => {
    run_after_focus(() => {
      Byond.command(command);
    });
  };
}

function draw_verbs(cat) {
  statcontentdiv.textContent = '';
  var table = document.createElement('div');
  var additions = {}; // additional sub-categories to be rendered
  table.className = 'grid-container';
  sortVerbs();
  if (split_admin_tabs && cat.lastIndexOf('.') != -1) {
    var splitName = cat.split('.');
    if (splitName[0] === 'Admin') cat = splitName[1];
  }
  verbs.reverse(); // sort verbs backwards before we draw
  for (var i = 0; i < verbs.length; ++i) {
    var part = verbs[i];
    var name = part[0];
    if (split_admin_tabs && name.lastIndexOf('.') != -1) {
      var splitName = name.split('.');
      if (splitName[0] === 'Admin') name = splitName[1];
    }
    var command = part[1];

    if (
      command &&
      name.lastIndexOf(cat, 0) != -1 &&
      (name.length == cat.length || name.charAt(cat.length) == '.')
    ) {
      var subCat = name.lastIndexOf('.') != -1 ? name.split('.')[1] : null;
      if (subCat && !additions[subCat]) {
        var newTable = document.createElement('div');
        newTable.className = 'grid-container';
        additions[subCat] = newTable;
      }

      var a = document.createElement('a');
      a.href = '#';
      a.onclick = make_verb_onclick(command.replace(/\s/g, '-'));
      a.className = 'grid-item';
      var t = document.createElement('span');
      t.textContent = command;
      t.className = 'grid-item-text';
      a.appendChild(t);
      (subCat ? additions[subCat] : table).appendChild(a);
    }
  }

  // Append base table to view
  var content = document.getElementById('statcontent');
  content.appendChild(table);

  // Append additional sub-categories if relevant
  for (var cat in additions) {
    if (Object.hasOwn(additions, cat)) {
      // do addition here
      var header = document.createElement('h3');
      header.textContent = cat;
      content.appendChild(header);
      content.appendChild(additions[cat]);
    }
  }
}

function set_theme(which) {
  if (which == 'light') {
    document.body.className = '';
    document.documentElement.className = 'light';
  } else if (which == 'dark') {
    document.body.className = 'dark';
    document.documentElement.className = 'dark';
  }
}

function set_font_size(size) {
  document.body.style.setProperty('font-size', size);
}

function set_tabs_style(style) {
  if (style == 'default') {
    menu.classList.add('menu-wrap');
    menu.classList.remove('tabs-classic');
  } else if (style == 'classic') {
    menu.classList.add('menu-wrap');
    menu.classList.add('tabs-classic');
  } else if (style == 'scrollable') {
    menu.classList.remove('menu-wrap');
    menu.classList.remove('tabs-classic');
  }
}

function is_statpanel_control(target) {
  while (target && target !== document) {
    if (
      target.tagName === "INPUT" ||
      target.tagName === "SELECT" ||
      target.tagName === "OPTION" ||
      target.tagName === "TEXTAREA" ||
      target.tagName === "BUTTON"
    ) {
      return true;
    }
    target = target.parentElement;
  }
  return false;
}

function restoreFocus(event) {
  if (
    (event && is_statpanel_control(event.target)) ||
    is_statpanel_control(document.activeElement)
  ) {
    return;
  }
  run_after_focus(() => {
    Byond.winset('map', {
      focus: true,
    });
  });
}

function getCookie(cname) {
  var name = cname + '=';
  var ca = document.cookie.split(';');
  for (var i = 0; i < ca.length; i++) {
    var c = ca[i];
    while (c.charAt(0) == ' ') c = c.substring(1);
    if (c.indexOf(name) === 0) {
      return decoder(c.substring(name.length, c.length));
    }
  }
  return '';
}

function add_verb_list(payload) {
  var to_add = payload; // list of a list with category and verb inside it
  to_add.sort(); // sort what we're adding
  for (var i = 0; i < to_add.length; i++) {
    var part = to_add[i];
    if (!part[0]) continue;
    var category = part[0];
    if (category.indexOf('.') != -1) {
      var splitName = category.split('.');
      if (split_admin_tabs && splitName[0] === 'Admin') category = splitName[1];
      else category = splitName[0];
    }
    if (findVerbindex(part[1], verbs)) continue;
    if (verb_tabs.includes(category)) {
      verbs.push(part);
      if (current_tab == category) {
        draw_verbs(category); // redraw if we added a verb to the tab we're currently in
      }
    } else if (category) {
      verb_tabs.push(category);
      verbs.push(part);
      createStatusTab(category);
    }
  }
}

document.addEventListener('mouseup', restoreFocus);
document.addEventListener('keyup', restoreFocus);

if (!current_tab) {
  addPermanentTab(defaultTab);
  tab_change(defaultTab);
}

window.onload = () => {
  Byond.sendMessage('Update-Verbs');
};

Byond.subscribeTo('remove_verb_list', (v) => {
  var to_remove = v;
  for (var i = 0; i < to_remove.length; i++) {
    remove_verb(to_remove[i]);
  }
  check_verbs();
  sortVerbs();
  if (verb_tabs.includes(current_tab)) draw_verbs(current_tab);
});

// passes a 2D list of (verbcategory, verbname) creates tabs and adds verbs to respective list
// example (IC, Say)
Byond.subscribeTo('init_verbs', (payload) => {
  wipe_verbs(); // remove all verb categories so we can replace them
  checkStatusTab(); // remove all status tabs
  verb_tabs = payload.panel_tabs;
  verb_tabs.sort(); // sort it
  var do_update = false;
  var cat = '';
  for (var i = 0; i < verb_tabs.length; i++) {
    cat = verb_tabs[i];
    createStatusTab(cat); // create a category if the verb doesn't exist yet
  }
  if (verb_tabs.includes(current_tab)) {
    do_update = true;
  }
  if (payload.verblist) {
    add_verb_list(payload.verblist);
    sortVerbs(); // sort them
    if (do_update) {
      draw_verbs(current_tab);
    }
  }
  SendTabsToByond();
});

Byond.subscribeTo('update_stat', (payload) => {
  status_tab_parts = [];

  var parsed = payload.global_data;

  for (var i = 0; i < parsed.length; i++)
    if (parsed[i] != null) status_tab_parts.push(parsed[i]);

  parsed = payload.other_str;

  for (var i = 0; i < parsed.length; i++)
    if (parsed[i] != null) status_tab_parts.push(parsed[i]);

  if (current_tab == 'Status') {
    draw_status();
  } else if (current_tab == 'Debug Stat Panel') {
    draw_debug();
  }
});

Byond.subscribeTo("update_mc", (payload) => {
  mc_tab_parts = payload.mc_data;
  mc_tick_summary = payload.tick_summary || {};
  mc_tick_summary.coord_entry = payload.coord_entry;
  mc_subsystems = payload.subsystems || [];

  if (!verb_tabs.includes("MC")) {
    verb_tabs.push("MC");
  }

  createStatusTab("MC");

  if (current_tab == "MC") {
    draw_mc();
  }
});

Byond.subscribeTo('create_debug', () => {
  if (!document.getElementById('Debug Stat Panel')) {
    addPermanentTab('Debug Stat Panel');
  } else {
    removePermanentTab('Debug Stat Panel');
  }
});

Byond.subscribeTo('create_listedturf', (TN) => {
  remove_listedturf(); // remove the last one if we had one
  turfname = TN;
  addPermanentTab(turfname);
  tab_change(turfname);
});

Byond.subscribeTo('remove_admin_tabs', () => {
  href_token = null;
  remove_mc();
  remove_tickets();
  remove_sdql2();
  remove_interviews();
});

Byond.subscribeTo('update_listedturf', (TC) => {
  turfcontents = TC;
  if (current_tab == turfname) {
    draw_listedturf();
  }
});

Byond.subscribeTo('update_interviews', (I) => {
  interviewManager = I;
  if (current_tab == 'Tickets') {
    draw_interviews();
  }
});

Byond.subscribeTo('update_split_admin_tabs', (status) => {
  status = status == true;

  if (split_admin_tabs !== status) {
    if (split_admin_tabs === true) {
      removeStatusTab('Events');
      removeStatusTab('Fun');
      removeStatusTab('Game');
    }
    update_verbs();
  }
  split_admin_tabs = status;
});

Byond.subscribeTo('add_admin_tabs', (ht) => {
  href_token = ht;
  addPermanentTab('MC');
  addPermanentTab('Tickets');
});

Byond.subscribeTo('update_sdql2', (S) => {
  sdql2 = S;
  if (sdql2.length > 0 && !verb_tabs.includes('SDQL2')) {
    verb_tabs.push('SDQL2');
    addPermanentTab('SDQL2');
  }
  if (current_tab == 'SDQL2') {
    draw_sdql2();
  }
});

Byond.subscribeTo('update_tickets', (T) => {
  tickets = T;
  if (!verb_tabs.includes('Tickets')) {
    verb_tabs.push('Tickets');
    addPermanentTab('Tickets');
  }
  if (current_tab == 'Tickets') {
    draw_tickets();
  }
});

Byond.subscribeTo('remove_listedturf', remove_listedturf);

Byond.subscribeTo('remove_sdql2', remove_sdql2);

Byond.subscribeTo('remove_mc', remove_mc);

Byond.subscribeTo('add_verb_list', add_verb_list);
