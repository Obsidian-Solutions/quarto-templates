/**
 * SPDX-License-Identifier: MIT
 * Reveal.js search plugin for Obsidian Solutions templates.
 * Enables CTRL+Shift+F to find text in slides.
 *
 * Based on: https://github.com/rajgoel/reveal.js-plugins/tree/master/search
 */

(function (Reveal) {
  'use strict';

  // Default configuration
  var defaultConfig = {
    toggle: true,
    hotkey: 'f',
    coverage: true,
    threshold: 0.5
  };

  function init(config) {
    config = Object.assign({}, defaultConfig, config);

    // Create search UI
    var searchDiv = document.createElement('div');
    searchDiv.className = 'reveal-search';
    searchDiv.innerHTML = [
      '<input type="text" class="reveal-search-input" placeholder="Search slides..." />',
      '<div class="reveal-search-results"></div>',
      '<div class="reveal-search-info"></div>'
    ].join('');

    document.querySelector('.reveal').appendChild(searchDiv);

    // Style the search UI
    var style = document.createElement('style');
    style.textContent = [
      '.reveal-search {',
      '  position: fixed;',
      '  top: 20px;',
      '  right: 20px;',
      '  z-index: 100;',
      '  background: #ffffff;',
      '  border: 1px solid #cecece;',
      '  padding: 10px;',
      '  display: none;',
      '  min-width: 300px;',
      '}',
      '.reveal-search-input {',
      '  width: 100%;',
      '  padding: 5px;',
      '  border: 1px solid #cecece;',
      '  font-family: inherit;',
      '  font-size: 14px;',
      '}',
      '.reveal-search-results {',
      '  max-height: 200px;',
      '  overflow-y: auto;',
      '  margin-top: 10px;',
      '}',
      '.reveal-search-result {',
      '  padding: 5px;',
      '  border-bottom: 1px solid #cecece;',
      '  cursor: pointer;',
      '}',
      '.reveal-search-result:hover {',
      '  background: #f3f3f3;',
      '}',
      '.reveal-search-result.current {',
      '  background: #e0e0e0;',
      '}',
      '.reveal-search-info {',
      '  font-size: 12px;',
      '  color: #484949;',
      '  margin-top: 5px;',
      '}',
      '.reveal-search-highlight {',
      '  background: #ffdd00;',
      '  padding: 1px 2px;',
      '}'
    ].join('\n');
    document.head.appendChild(style);

    var searchInput = searchDiv.querySelector('.reveal-search-input');
    var searchResults = searchDiv.querySelector('.reveal-search-results');
    var searchInfo = searchDiv.querySelector('.reveal-search-info');

    var currentMatches = [];
    var currentIndex = 0;

    // Toggle search
    function toggleSearch() {
      if (searchDiv.style.display === 'none' || searchDiv.style.display === '') {
        searchDiv.style.display = 'block';
        searchInput.focus();
      } else {
        searchDiv.style.display = 'none';
        clearHighlights();
      }
    }

    // Clear highlights
    function clearHighlights() {
      document.querySelectorAll('.reveal-search-highlight').forEach(function (el) {
        el.outerHTML = el.innerHTML;
      });
    }

    // Search through slides
    function search(query) {
      clearHighlights();
      currentMatches = [];
      currentIndex = 0;

      if (query.length < 2) {
        searchResults.innerHTML = '';
        searchInfo.textContent = '';
        return;
      }

      var slides = document.querySelectorAll('.reveal .slides section');
      slides.forEach(function (slide, slideIndex) {
        var text = slide.textContent;
        if (text.toLowerCase().indexOf(query.toLowerCase()) !== -1) {
          currentMatches.push({
            slide: slide,
            slideIndex: slideIndex,
            text: text
          });
        }
      });

      // Update results display
      searchResults.innerHTML = '';
      if (currentMatches.length === 0) {
        searchInfo.textContent = 'No results found';
        return;
      }

      searchInfo.textContent = currentMatches.length + ' slide(s) found';
      currentMatches.forEach(function (match, index) {
        var result = document.createElement('div');
        result.className = 'reveal-search-result';
        result.textContent = 'Slide ' + (match.slideIndex + 1) + ': ' + match.text.substring(0, 50) + '...';
        result.onclick = function () {
          Reveal.slide(match.slideIndex);
          currentIndex = index;
          updateCurrentResult();
        };
        searchResults.appendChild(result);
      });

      updateCurrentResult();
    }

    // Update current result highlight
    function updateCurrentResult() {
      document.querySelectorAll('.reveal-search-result').forEach(function (el, i) {
        el.classList.toggle('current', i === currentIndex);
      });
    }

    // Navigate results
    function nextResult() {
      if (currentMatches.length === 0) return;
      currentIndex = (currentIndex + 1) % currentMatches.length;
      Reveal.slide(currentMatches[currentIndex].slideIndex);
      updateCurrentResult();
    }

    function prevResult() {
      if (currentMatches.length === 0) return;
      currentIndex = (currentIndex - 1 + currentMatches.length) % currentMatches.length;
      Reveal.slide(currentMatches[currentIndex].slideIndex);
      updateCurrentResult();
    }

    // Event listeners
    searchInput.addEventListener('input', function () {
      search(this.value);
    });

    document.addEventListener('keydown', function (event) {
      if (event.ctrlKey && event.shiftKey && event.key === config.hotkey.toUpperCase()) {
        event.preventDefault();
        toggleSearch();
      } else if (event.key === 'Escape' && searchDiv.style.display === 'block') {
        toggleSearch();
      } else if (event.key === 'Enter' && searchDiv.style.display === 'block') {
        if (event.shiftKey) {
          prevResult();
        } else {
          nextResult();
        }
      }
    });
  }

  // Register plugin
  Reveal.Search = function (config) {
    init(config || {});
  };
})(Reveal);
