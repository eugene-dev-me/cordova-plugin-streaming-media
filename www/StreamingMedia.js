"use strict";
function StreamingMedia() {
}

StreamingMedia.prototype.playAudio = function (url, options) {
	options = options || {};
	cordova.exec(options.successCallback || null, options.errorCallback || null, "StreamingMedia", "playAudio", [url, options]);
};

StreamingMedia.prototype.pauseAudio = function (options) {
    options = options || {};
    cordova.exec(options.successCallback || null, options.errorCallback || null, "StreamingMedia", "pauseAudio", [options]);
};

StreamingMedia.prototype.resumeAudio = function (options) {
    options = options || {};
    cordova.exec(options.successCallback || null, options.errorCallback || null, "StreamingMedia", "resumeAudio", [options]);
};

StreamingMedia.prototype.stopAudio = function (options) {
    options = options || {};
    cordova.exec(options.successCallback || null, options.errorCallback || null, "StreamingMedia", "stopAudio", [options]);
};

StreamingMedia.prototype.playVideoAsset = function (asset_id, options) {
	options = options || {};
	cordova.exec(options.successCallback || null, options.errorCallback || null, "StreamingMedia", "playVideoAsset", [asset_id, options]);
};

StreamingMedia.prototype.playVideoURL = function (url, options) {
	options = options || {};
	cordova.exec(options.successCallback || null, options.errorCallback || null, "StreamingMedia", "playVideoURL", [url, options]);
};



StreamingMedia.install = function () {
	if (!window.plugins) {
		window.plugins = {};
	}
	window.plugins.streamingMedia = new StreamingMedia();
	return window.plugins.streamingMedia;
};

cordova.addConstructor(StreamingMedia.install);