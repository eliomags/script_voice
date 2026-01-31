// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// Custom hooks for mobile-first interactions
let Hooks = {}

// Audio player hook
Hooks.AudioPlayer = {
  mounted() {
    this.audio = this.el.querySelector('audio')
    if (this.audio) {
      this.audio.addEventListener('timeupdate', () => {
        const progress = (this.audio.currentTime / this.audio.duration) * 100
        this.pushEvent('audio_progress', {progress: progress})
      })

      this.audio.addEventListener('ended', () => {
        this.pushEvent('audio_ended', {})
      })

      this.audio.addEventListener('loadedmetadata', () => {
        const duration = this.formatDuration(this.audio.duration)
        this.pushEvent('audio_loaded', {duration: duration})
      })
    }
  },

  formatDuration(seconds) {
    const mins = Math.floor(seconds / 60)
    const secs = Math.floor(seconds % 60)
    return `${mins}:${secs.toString().padStart(2, '0')}`
  }
}

// File drop zone hook
Hooks.FileDropZone = {
  mounted() {
    const el = this.el

    // Prevent default drag behaviors
    ;['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
      el.addEventListener(eventName, (e) => {
        e.preventDefault()
        e.stopPropagation()
      })
    })

    // Highlight drop zone
    ;['dragenter', 'dragover'].forEach(eventName => {
      el.addEventListener(eventName, () => {
        el.classList.add('border-emerald-500', 'bg-emerald-50')
      })
    })

    ;['dragleave', 'drop'].forEach(eventName => {
      el.addEventListener(eventName, () => {
        el.classList.remove('border-emerald-500', 'bg-emerald-50')
      })
    })
  }
}

// Video recorder hook (for verification)
Hooks.VideoRecorder = {
  mounted() {
    this.mediaRecorder = null
    this.chunks = []

    this.el.addEventListener('click', async () => {
      try {
        const stream = await navigator.mediaDevices.getUserMedia({
          video: { facingMode: 'user', width: 640, height: 480 },
          audio: true
        })

        this.startRecording(stream)
      } catch (err) {
        console.error('Error accessing camera:', err)
        this.pushEvent('video_error', {message: 'Could not access camera'})
      }
    })
  },

  startRecording(stream) {
    this.chunks = []
    this.mediaRecorder = new MediaRecorder(stream)

    this.mediaRecorder.ondataavailable = (e) => {
      if (e.data.size > 0) {
        this.chunks.push(e.data)
      }
    }

    this.mediaRecorder.onstop = () => {
      const blob = new Blob(this.chunks, { type: 'video/webm' })
      // In production, upload blob to server
      this.pushEvent('video_recorded', {})
      stream.getTracks().forEach(track => track.stop())
    }

    this.mediaRecorder.start()

    // Auto-stop after 10 seconds
    setTimeout(() => {
      if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
        this.mediaRecorder.stop()
      }
    }, 10000)

    this.pushEvent('recording_started', {})
  }
}

// Touch-friendly scroll snap for horizontal scrolling
Hooks.HorizontalScroll = {
  mounted() {
    const el = this.el
    let isDown = false
    let startX
    let scrollLeft

    el.addEventListener('mousedown', (e) => {
      isDown = true
      startX = e.pageX - el.offsetLeft
      scrollLeft = el.scrollLeft
    })

    el.addEventListener('mouseleave', () => {
      isDown = false
    })

    el.addEventListener('mouseup', () => {
      isDown = false
    })

    el.addEventListener('mousemove', (e) => {
      if (!isDown) return
      e.preventDefault()
      const x = e.pageX - el.offsetLeft
      const walk = (x - startX) * 2
      el.scrollLeft = scrollLeft - walk
    })
  }
}

// Intersection observer for lazy loading
Hooks.LazyLoad = {
  mounted() {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          this.pushEvent('visible', {})
          observer.unobserve(this.el)
        }
      })
    }, { threshold: 0.1 })

    observer.observe(this.el)
  }
}

// LiveSocket configuration
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks,
  dom: {
    // Preserve scroll position on LiveView updates
    onBeforeElUpdated(from, to) {
      if (from._x_dataStack) {
        window.Alpine.clone(from, to)
      }
    }
  }
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#059669"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Handle native share API
window.addEventListener("phx:share", (e) => {
  if (navigator.share) {
    navigator.share({
      title: e.detail.title,
      text: e.detail.text,
      url: e.detail.url
    })
  }
})

// Handle clipboard copy
window.addEventListener("phx:copy", (e) => {
  if (navigator.clipboard) {
    navigator.clipboard.writeText(e.detail.text).then(() => {
      // Show feedback
      const el = document.getElementById(e.detail.id)
      if (el) {
        el.textContent = 'Copied!'
        setTimeout(() => {
          el.textContent = e.detail.originalText || 'Copy'
        }, 2000)
      }
    })
  }
})

// Prevent zoom on double-tap for iOS
let lastTouchEnd = 0
document.addEventListener('touchend', (e) => {
  const now = Date.now()
  if (now - lastTouchEnd <= 300) {
    e.preventDefault()
  }
  lastTouchEnd = now
}, false)

// Connect if there are any LiveViews on the page
liveSocket.connect()

// Expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
