// OWServer Plugin for Vera
// For: Embedded Data Systems
// (c) Chris Jackson
// Modifications to eliminate the dependence on prototypejs by a-lurker July 2020
// Further mods Jan 2022 to fix object list indexing issue

let m_newDevices = [];
let m_deviceCaps = [];
let m_typeTable  = [];

let URL           = '/port_3480/data_request';
let PLUGIN_URL_ID = 'lr_owCtrl';

function ajaxRequest(url, args, onSuccess, onError) {
   // append any args to the url
   let first = true;
   for (let prop in args) {
      url += (first ? "?" : "&") + prop + "=" + args[prop];
      first = false;
   }

   // Internet Explorer (IE5 and IE6) use an ActiveX object instead of
   // the XMLHttpRequest object. We will not support those versions.
   let httpRequest = new XMLHttpRequest();
   if (!httpRequest) {
      alert('Cannot create httpRequest instance. Get an up-to-date browser!');
      return;
   }

   // Return the whole httpRequest object, so it can be picked
   // to pieces by the two callbacks as needed. Typically
   // ony responseText and responseXML will be of interest.
   httpRequest.onreadystatechange = function() {
        if (this.readyState == 4) {
            if (this.status != 200) {
                if (typeof onError == 'function') {
                    onError(this);
                }
            }
            else if (typeof onSuccess == 'function') {
                onSuccess(this);
            }
        }
   };

   // use GET and asynchronous operation
   httpRequest.open("GET", url, true);
   httpRequest.send();
}

// Register the devices...
function OWpluginRegister()
{
   // loop through the devices
   let newDeviceCnt = 0;
   let args = {id: PLUGIN_URL_ID, funct: 'create'};

   for (let iDevice in m_newDevices) {
      newDeviceCnt++;

      let elSelect = document.getElementById('OWVar-'+iDevice);
      m_newDevices[iDevice].Type = elSelect.value;

      args["Rom"+newDeviceCnt] = m_newDevices[iDevice].ROMId;
      args["Dev"+newDeviceCnt] = m_newDevices[iDevice].Device;
      args["Typ"+newDeviceCnt] = m_newDevices[iDevice].Type;
   }

   if (newDeviceCnt == 0) return;

   args.cnt = newDeviceCnt;

   ajaxRequest(
      URL,
      args,
      function() {
         // refer to: http://wiki.micasaverde.com/index.php/JavaScript_API#set_panel_html_.28html.29
         set_panel_html("Configuration sent!. Luup Engine will restart and the new device(s) should take effect.");
      },
   null);
}

// display the result
function onSuccess3(httpRequest) {
   try {m_newDevices = JSON.parse(httpRequest.responseText); }
   catch(e) {
       console.log("Error: json parsing failed - refer to next console output line");
       console.log(e);
       set_panel_html("Error: json parsing failed");
       return;
   }

   let innerHTML = "";
   let lastId    = "";
   let style     = "";
   let deviceCnt = 0;

   // loop through the devices in the m_newDevices list and see how many there are.
   // m_newDevices is not an array. It's list of objects - as are m_deviceCaps and m_typeTable
   for (let aDevice in m_newDevices) { deviceCnt ++; }

   if (deviceCnt == 0) {
      innerHTML = "There are no new devices to add";
   }
   else {
      innerHTML = "<div style='width:570px;' id='OWServer-device-list'>" +
               "<div style=\"border-bottom:2px solid red;margin:6px;\">" +
               "<table><tr>"+
               "<td width='160px'>Total NEW devices: <b>" + deviceCnt + "</b></td>" +
               "<td><input type='button' onclick='OWpluginRegister();' value='Add'></td>" +
               "<td width='30px'>&nbsp;</td>" +
               "<td>Check <b>ALL</b> entries before clicking the Add button.</td>" +
               "</tr></table></div>";

      // loop through all the new devices
      for (let iDevice in m_newDevices) {
         if (m_newDevices[iDevice].ROMId != lastId) {
            style  = "border-top:3px solid green;margin:2px;";
            lastId = m_newDevices[iDevice].ROMId;
         }
         else
            style = "border-top:1px solid blue;margin:2px;";

         // new Device header
         innerHTML += "<div style='" + style + "'>" +
                          "<table><tr>"+
                          "<td width='115'>Device: " + m_deviceCaps[m_newDevices[iDevice].Device].Device  + "</td>" +
                          "<td width='140'>" + m_newDevices[iDevice].ROMId + "</td>" +
                          "<td width='130'>" + m_deviceCaps[m_newDevices[iDevice].Device].Name + "</td>" +
                          "<td><form>" +
                          "<select id='OWVar-" + iDevice + "' style='width:185px'>";

         let numOptions = m_deviceCaps[m_newDevices[iDevice].Device].Services.length;
         for (let iOpt=0; iOpt<numOptions; iOpt++) {
            innerHTML += "<option value='" + m_deviceCaps[m_newDevices[iDevice].Device].Services[iOpt] + "'>" + m_typeTable[m_deviceCaps[m_newDevices[iDevice].Device].Services[iOpt]].Name + "</option>";
         }

         innerHTML += "</select>" +
                    "</form></td>" +
                    "</tr></table></div>";
      }
      innerHTML += "</div>";
   }
   // refer to: http://wiki.micasaverde.com/index.php/JavaScript_API#set_panel_html_.28html.29
   set_panel_html(innerHTML);
}

// Populate the Device List
function onSuccess2(httpRequest)
{
   m_deviceCaps = JSON.parse(httpRequest.responseText);

   let args = {
      id:    PLUGIN_URL_ID,
      funct: "getnew"
   };
   ajaxRequest(URL, args, onSuccess3, null);
}

// Get the Device Table
function onSuccess1(httpRequest)
{
   m_typeTable = JSON.parse(httpRequest.responseText);

   let args = {
      id:    PLUGIN_URL_ID,
      funct: "getdevcap"
   };
   ajaxRequest(URL, args, onSuccess2, null);
}

// Get the Type Table
function showDevices()
{
   let args = {
      id:    PLUGIN_URL_ID,
      funct: "gettypes"
   };
   ajaxRequest(URL, args, onSuccess1, null);

   return true;
}
