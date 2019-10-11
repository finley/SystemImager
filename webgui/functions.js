//
// SystemImager
// vi: set filetype=javascript et ts=4:
//
//
//

function ProgressBar(value,unit) {
    return '<div><div class="progress_bar" style="width:' + value + unit +'">' + value + unit + '</div></div>';
}

function StatusToText(value) {
    if (value < 0) {
      return "<span class='status0'>FAILED</span>";
    } else if (value < 100) {
      return ProgressBar(value,"%");
      // return "Progress: " + value + "%";
    } else {
      var index = value - 100;
      var my_statuses = ['Imaged','Finalizing...','REBOOTED','Beeping','Rebooting...','Shutdown','Shell','Extracting...','Pre-Install','Post-Install'];
      if ( index <= my_statuses.length+1 ) {
        return "<span class='status" + value + "'>" + my_statuses[index] + "</span>";
      } else {
        return "Unknown (<span class='status0'>" + (value) + ")</span>";
      }
    }
}

function UnixDate(unix_timestamp) {
    var months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    var start_date = new Date(unix_timestamp * 1000);
    var hours = start_date.getHours();
    var minutes = "0" + start_date.getMinutes();
    var seconds = "0" + start_date.getSeconds();
    var my_time = hours + ':' + minutes.substr(-2) + ':' + seconds.substr(-2);
    var day = start_date.getDay();
    var month = months[start_date.getMonth()];
    var year = start_date.getFullYear();
    var my_date = day + ' ' + month + ' ' + year;
    return(my_time + " - " + my_date);
}
