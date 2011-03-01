
var controls = [];

function $(id){
    return document.getElementById(id);
}

function activate(id){
    for(var i = 0; i < controls.length; i++){
        if(controls[i] == id){
            $(controls[i]).className = "active-tab";
            $("view_" + controls[i]).style.display = "block";
        } else {
            $(controls[i]).className = "inactive-tab";
            $("view_" + controls[i]).style.display = "none";
        }
    }
}

/* Before calling the function to generate tabs, the following variables should ve
 * supplied with values as follows:
 *      generateTab(
 *             headings = [heading1, heading2, ..., heading(n)],
 *             content = {
 *                         "heading1":"",
 *                         "heading2":"",
 *                             .
 *                             .
 *                             .
 *                         "heading(n)":""
 *                       },
 *             [target = control to attach tab to defaulted to document.body]);
*/
function generateTab(headings, content, target){
    var tabMainContainer = document.createElement("div");
    tabMainContainer.id = "tabMainContainer";

    if(target){
        target.innerHTML = "";
        target.appendChild(tabMainContainer);
    } else {
        document.body.appendChild(tabMainContainer);
    }

    var tabContainer = document.createElement("div");
    tabContainer.id = "tabContainer";

    tabMainContainer.appendChild(tabContainer);

    var tabPageContainer = document.createElement("div");
    tabPageContainer.id = "tabPageContainer";
    
    tabMainContainer.appendChild(tabPageContainer);

    for(var i = 0; i < headings.length; i++){
        var tab = document.createElement("div");
        tab.id = "tab" + (i + 1);
        if(i == 0){
            tab.className = "active-tab";
            tab.style.marginLeft = "7px";
        } else {
            tab.className = "inactive-tab";
            tab.style.marginLeft = "1px";
        }
        tab.innerHTML = "<span>" + headings[i] + "</span>";
        tab.onclick = function(){
            activate(this.id);
        }
        tabContainer.appendChild(tab);
        controls.push(tab.id);
        
        var tabPage = document.createElement("div");
        tabPage.id = "view_tab" + (i + 1);
        tabPage.className = "view";

        if(i == 0){
            tabPage.style.display = "block";
        } else {
            tabPage.style.display = "none";
        }

        if(content[headings[i]]){
            tabPage.innerHTML = content[headings[i]];
        } else {
            tabPage.innerHTML = "<h3>" + headings[i] + "</h3>";
        }

        tabPageContainer.appendChild(tabPage);
    }
}

//window.addEventListener("load", generateTab, false);
