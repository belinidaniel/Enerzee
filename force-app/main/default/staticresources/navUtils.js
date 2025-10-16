/**
 * Navigation utility methods.
 * @namespace navUtils
 */
window.navUtils = (function () {
  /**
   * Determines whether this is running in a DocuSign for Salesforce iFrame.
   * @returns {boolean} True if this is running in our iFrame, false otherwise.
   */
  var isInIFrame = function () {
    var inIFrame;
    try {
      // Check to see if we can talk to the parent.
      inIFrame = window.self !== window.parent && window.parent.navUtils && (!!parent.navUtils.isInIFrame);
    } catch (e) {
      inIFrame = false;
    }
    return inIFrame;
  };

  var _isLightningOrMobile = function () {
    return typeof sforce !== 'undefined' && sforce && (!!sforce.one);
  };

  /**
   * Navigates to a Salesforce object.
   * @param id {string} The ID of the target object.
   * @param pathPrefix {string} The path prefix, if any.
   */
  var navigateToSObject = function (id, pathPrefix) {
    if (isInIFrame()) {
      window.parent.navUtils.navigateToSObject(id, pathPrefix);
    } else if (_isLightningOrMobile()) {
      sforce.one.navigateToSObject(id);
    } else {
      window.location.href = (pathPrefix) ? pathPrefix + '/' + id : '/' + id;
    }
  };

  /**
   * Fires a URL navigation event.
   * @param url {string} The URL to navigate to.
   * @param isRedirect {boolean} Whether or not the navigation is a redirect. Leave undefined if calling from a Lightning component.
   */
  var navigateToUrlOnlineEditor = function (url, isRedirect) {
    if (!isRedirect && typeof $A !== 'undefined' && $A) {
      var navEvt = $A.get('e.force:navigateToURL');
      if (!$A.util.isEmpty(navEvt)) {
        navEvt.setParams({
          'url': url
        });
        navEvt.fire();
      }
    } else if (_isLightningOrMobile()) {
      sforce.one.navigateToURL(url, isRedirect);
    } else {
      window.location.href = url;
    }
  };

  /**
   * Fires a URL navigation event.
   * @param url {string} The URL to navigate to.
   */

  var navigateToUrl = function (url) {
    if (_isLightningOrMobile()) {
      sforce.one.navigateToURL(url);
    } else {
      var navEvt = $A.get('e.force:navigateToURL');
      if (!$A.util.isEmpty(navEvt)) {
        navEvt.setParams({
          'url': url
        });
        navEvt.fire();
      }
    }
  };

  /**
   * Checks to see if users current browser is running IE 11 or earlier.
   */

  var isIE = function isIE() {
    var agent = window.navigator.userAgent;
    return agent.indexOf('MSIE ') > 0 || agent.indexOf('Trident/') > 0;
  }; 

  return Object.freeze({
    isInIFrame: isInIFrame,
    navigateToSObject: navigateToSObject,
    navigateToUrl: navigateToUrl,
    navigateToUrlOnlineEditor: navigateToUrlOnlineEditor,
    isLightningOrMobile: _isLightningOrMobile,
    isIE: isIE
  });
}());
Quicklinks
Profiles Chamber
Quick Console
Home
Quick Query
Execute Anonymous
Sobject fields
Quick ORG Describe
Replace API Names
Convert SF Id
Login As...
Options
Hide
Learn Apex Now