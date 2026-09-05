/**
 * SPDX-License-Identifier: MIT
 * Reveal.js spotlight plugin for Obsidian Solutions templates.
 * Enables a presenter to highlight specific content during demos.
 *
 * Based on: https://github.com/denniskniep/reveal.js-plugin-spotlight
 */

(function (Reveal) {
  'use strict';

  // Default configuration
  var defaultConfig = {
    toggleSpotlightButton: true,
    spotlightButtonColor: '#ffffff',
    spotlightBackgroundColor: 'rgba(0, 0, 0, 0.8)',
    spotlightOnColor: '#ffffff',
    spotlightOffColor: 'rgba(0, 0, 0, 0.3)',
    spotlightSize: 100,
    spotlightCursor: 'none'
  };

  function init(config) {
    config = Object.assign({}, defaultConfig, config);

    var isSpotlightOn = false;
    var spotlightElement = null;

    // Create spotlight element
    spotlightElement = document.createElement('div');
    spotlightElement.className = 'reveal-spotlight';
    spotlightElement.style.cssText = [
      'position: fixed;',
      'width: ' + config.spotlightSize + 'px;',
      'height: ' + config.spotlightSize + 'px;',
      'border-radius: 50%;',
      'pointer-events: none;',
      'z-index: 9999;',
      'display: none;',
      'transition: all 0.3s ease;'
    ].join('');
    document.body.appendChild(spotlightElement);

    // Create toggle button
    if (config.toggleSpotlightButton) {
      var button = document.createElement('button');
      button.className = 'reveal-spotlight-button';
      button.innerHTML = '&#9788;'; // Sun icon
      button.title = 'Toggle Spotlight';
      button.style.cssText = [
        'position: fixed;',
        'bottom: 20px;',
        'right: 20px;',
        'z-index: 10000;',
        'background: ' + config.spotlightButtonColor + ';',
        'border: 1px solid #cecece;',
        'border-radius: 50%;',
        'width: 40px;',
        'height: 40px;',
        'cursor: pointer;',
        'font-size: 20px;',
        'display: flex;',
        'align-items: center;',
        'justify-content: center;'
      ].join('');
      document.querySelector('.reveal').appendChild(button);

      button.addEventListener('click', function () {
        toggleSpotlight();
      });
    }

    // Style the spotlight
    var style = document.createElement('style');
    style.textContent = [
      '.reveal-spotlight.on {',
      '  display: block;',
      '  background: ' + config.spotlightOnColor + ';',
      '  mix-blend-mode: screen;',
      '}',
      '.reveal-spotlight.off {',
      '  display: block;',
      '  background: ' + config.spotlightOffColor + ';',
      '}',
      '.reveal.spotlight-active .reveal-slide {',
      '  filter: brightness(0.3);',
      '}',
      '.reveal.spotlight-active .reveal-slide.past,',
      '.reveal.spotlight-active .reveal-slide.future {',
      '  filter: brightness(0.1);',
      '}'
    ].join('\n');
    document.head.appendChild(style);

    // Toggle spotlight
    function toggleSpotlight() {
      isSpotlightOn = !isSpotlightOn;
      if (isSpotlightOn) {
        document.body.style.cursor = config.spotlightCursor;
        document.querySelector('.reveal').classList.add('spotlight-active');
        spotlightElement.classList.add('on');
        spotlightElement.classList.remove('off');
      } else {
        document.body.style.cursor = '';
        document.querySelector('.reveal').classList.remove('spotlight-active');
        spotlightElement.classList.remove('on');
        spotlightElement.classList.add('off');
      }
    }

    // Track mouse position
    document.addEventListener('mousemove', function (event) {
      if (isSpotlightOn) {
        var x = event.clientX - config.spotlightSize / 2;
        var y = event.clientY - config.spotlightSize / 2;
        spotlightElement.style.left = x + 'px';
        spotlightElement.style.top = y + 'px';
      }
    });

    // Keyboard shortcut
    document.addEventListener('keydown', function (event) {
      if (event.key === 's' && !event.ctrlKey && !event.altKey && !event.metaKey) {
        // Don't trigger if user is typing in an input
        if (event.target.tagName !== 'INPUT' && event.target.tagName !== 'TEXTAREA') {
          toggleSpotlight();
        }
      }
    });
  }

  // Register plugin
  Reveal.Spotlight = function (config) {
    init(config || {});
  };
})(Reveal);
