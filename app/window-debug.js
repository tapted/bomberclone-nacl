chrome.app.runtime.onLaunched.addListener(function() {
  chrome.app.window.create('main-debug.html', {
    'width': 640,
    'height': 480
  });
});
