// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import { hooks as colocatedHooks } from "phoenix-colocated/oneoffchat"
import topbar from "../vendor/topbar"

let Hooks = {}

Hooks.ConnectionMonitor = {
  mounted() {
    this.input = document.querySelector("textarea[name='message']");
    this.banner = document.getElementById("connection-banner");
    this.sendButton = this.el.querySelector("#send-button");
    this.wasOffline = false;

    // Helper to trigger the Offline UI state
    this.goOffline = () => {
      if (this.wasOffline) return;
      this.wasOffline = true;

      // Disable input and update placeholder
      this.input.setAttribute("disabled", "true");
      this.sendButton.setAttribute("disabled", "true");
      this.input.placeholder = "Disconnected.";

      // Show the red warning banner
      this.banner.textContent = "You're offline. Check your connection.";
      // Using absolute/fixed positioning so it overlays perfectly
      this.banner.className = "p-2 text-center text-sm font-bold text-white bg-nord-11 absolute top-0 left-0 w-full z-50 transition-all duration-300";
    };

    // Helper to trigger the Online UI state
    this.goOnline = () => {
      if (!this.wasOffline) return;
      this.wasOffline = false;

      // Re-enable input
      this.input.removeAttribute("disabled");
      this.input.placeholder = "Type a message...";

      // Note: We don't touch the send button here because your
      // `.ClearInput` hook already handles the button state perfectly based on input.value!

      // Show the green success banner
      this.banner.textContent = "You're back online!";
      this.banner.className = "p-2 text-center text-sm font-bold text-white bg-nord-14 absolute top-0 left-0 w-full z-50 transition-all duration-300";

      // Hide the banner after 3 seconds
      setTimeout(() => {
        if (!this.wasOffline) this.banner.className = "hidden";
      }, 3000);
    };

    // --- 1. Catch Hard Drops (Browser loses WiFi) ---
    window.addEventListener("offline", this.goOffline);
    window.addEventListener("online", this.goOnline);

    // --- 2. Catch Soft Drops (Server restarts / Socket drops) ---
    window.addEventListener("phx:page-loading-start", (e) => {
      // LiveView dispatches this event for page navigations too.
      // We only want to trigger offline mode if the 'kind' is an error (socket drop).
      if (e.detail?.info?.kind === "error") {
        this.goOffline();
      }
    });

    window.addEventListener("phx:page-loading-stop", () => {
      // If the socket successfully reconnects and stops loading,
      // and the browser confirms we have internet, restore the UI!
      if (this.wasOffline && navigator.onLine) {
        this.goOnline();
      }
    });
  }
}

Hooks.MentionAutocomplete = {
  mounted() {
    this.el.addEventListener('keydown', (e) => {
      // Only intercept if the user hits the Tab key
      if (e.key === 'Tab') {

        // 1. Find exactly where the cursor is right now
        const cursorPosition = this.el.selectionStart;

        // 2. Grab all the text from the start of the input up to the cursor
        const textBeforeCursor = this.el.value.slice(0, cursorPosition);

        // 3. Regex check: Does the text right before the cursor look like "@something"?
        const match = textBeforeCursor.match(/@([a-zA-Z0-9_]+)$/);

        if (match) {
          // Prevent the browser's default Tab behavior immediately!
          e.preventDefault();

          // Extract the partial name (e.g., "joh")
          const typedName = match[1];

          // 4. THE FIX: Ask the server to search for this specific string
          // The third argument is the callback function that waits for your {:reply, ...}
          this.pushEvent("search_mentions", { query: typedName }, (reply) => {
            
            // Check if the server found anyone
            if (reply.matches && reply.matches.length > 0) {
              
              // Emulate your old behavior: just grab the very first match the server returned
              const foundUser = reply.matches[0]; 

              // We found a match! Grab the rest of the text after the cursor
              const textAfterCursor = this.el.value.slice(cursorPosition);

              // Replace the partial "@joh" with the full "@JohnDoe "
              const newTextBeforeCursor = textBeforeCursor.replace(/@([a-zA-Z0-9_]+)$/, `@${foundUser} `);

              // Update the input field
              this.el.value = newTextBeforeCursor + textAfterCursor;

              // Put the cursor exactly at the end of the newly inserted username
              const newCursorPos = newTextBeforeCursor.length;
              this.el.setSelectionRange(newCursorPos, newCursorPos);

              // Trigger the 'input' event so the Send button hook re-evaluates
              this.el.dispatchEvent(new Event('input', { bubbles: true }));
            }
          });
        }
      }
    });
  }
}

Hooks.ChatScrollKeeper = {
  beforeUpdate() {
    // 1. Use Math.abs() to convert negative scroll values into positive ones.
    // Now, -500 becomes 500, and 500 <= 5 evaluates correctly to false!
    this.isAtBottom = Math.abs(this.el.scrollTop) <= 5;

    // 2. Take a snapshot of the exact height and position before LiveView wipes the DOM
    this.oldScrollHeight = this.el.scrollHeight;
    this.oldScrollTop = this.el.scrollTop;
  },

  updated() {
    if (this.isAtBottom) {
      // If they are reading the newest messages, keep them pinned to the bottom (0)
      this.el.scrollTop = 0;
    } else {
      // Calculate exactly how many pixels of new messages were just added to the DOM
      const heightDifference = this.el.scrollHeight - this.oldScrollHeight;

      if (this.oldScrollTop < 0) {
        // Modern Browsers: Push the scroll further negative by the exact height of the new message
        this.el.scrollTop = this.oldScrollTop - heightDifference;
      } else {
        // Fallback for older browsers that use positive scroll math
        this.el.scrollTop = this.oldScrollTop + heightDifference;
      }
    }
  }
}

// Hooks.PlayMentionSound = {
//   mounted() {    
//     const audio = new Audio('/audio/ping.mp3'); 

//     // 2. Play the sound. We catch errors because browsers will block 
//     // audio if the user hasn't clicked or typed anywhere on the page yet.
//     audio.play().catch(error => {
//       console.log("Browser blocked autoplay:", error);
//     });
//   }
// };

window.addEventListener("phx:play_background_ping", (e) => {
  const audio = new Audio('/audio/ping.mp3');
  audio.play().catch(error => {
    console.log("Browser blocked background autoplay:", error);
  });
});

class LocalTime extends HTMLElement {
  connectedCallback() {
    const rawTimestamp = this.getAttribute("datetime");
    if (!rawTimestamp) return;

    const options = {
      year: "numeric",
      month: "long",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    }

    this.setAttribute("title", new Date(rawTimestamp).toLocaleString('en-US', options));

    const date = new Date(rawTimestamp);
    const now = new Date();

    // Calculate the difference in milliseconds, then convert to hours
    const diffInMs = now.getTime() - date.getTime();
    const diffInHours = diffInMs / (1000 * 60 * 60);

    if (diffInHours < 24) {
      // 1. RECENT MESSAGES (< 24 hours): Show "13:27"
      this.innerText = new Intl.DateTimeFormat('en-US', {
        hour: '2-digit',
        minute: '2-digit',
        hour12: false
      }).format(date);

    } else {
      // 2. OLDER MESSAGES: Scale to Days, Months, or Years
      const diffInDays = diffInHours / 24;
      const rtf = new Intl.RelativeTimeFormat('en-US', { numeric: 'auto' });

      if (diffInDays < 30) {
        // Less than a month: "3 days ago", "yesterday"
        this.innerText = rtf.format(-Math.round(diffInDays), 'day');

      } else if (diffInDays < 365) {
        // Between 1 and 12 months: "2 months ago", "last month"
        const diffInMonths = Math.round(diffInDays / 30);
        this.innerText = rtf.format(-diffInMonths, 'month');

      } else {
        // Over a year: "1 year ago", "2 years ago"
        const diffInYears = Math.round(diffInDays / 365);
        this.innerText = rtf.format(-diffInYears, 'year');
      }
    }
  }
}

// Register our tag with the browser
window.customElements.define("local-time", LocalTime);

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: { ...colocatedHooks, ...Hooks },
})

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#81a1c1" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({ detail: reloader }) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if (keyDown === "c") {
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if (keyDown === "d") {
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

