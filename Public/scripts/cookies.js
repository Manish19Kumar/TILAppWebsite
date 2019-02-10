// cookiesConfirmed
// 1. Define a function, cookiesConfirmed(), that the browser calls when the user clicks the OK link in the cookie message.
function cookiesConfirmed() {
    // 2. Hide the cookie message.
    $('cookie-footer').hide();
    // 3. Create a date that’s one year in the future. Then, create the expires string required for the cookie. By default, cookies are valid for the browser session — when the user closes the browser window or tab, the browser deletes the cookie. Adding the date ensures the browser persists the cookie for a year.
    var d = new Date();
    d.setTime(d.getTime() + (365*24*60*60*1000));
    var expires = "expires=" + d.toUTCString();
    // 4. Add a cookie called cookies-accepted to the page using JavaScript. You’ll check to see if this cookie exists when working out whether to show the cookie consent message.
    document.cookie = "cookies-accepted=true;" + expires;
}
