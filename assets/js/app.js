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
    this.stream = null
    this.chunks = []
    this.videoBlob = null

    // DOM elements
    this.videoPreview = this.el.querySelector('#video-preview')
    this.videoPlayback = this.el.querySelector('#video-playback')
    this.startBtn = this.el.querySelector('#start-recording-btn')
    this.stopBtn = this.el.querySelector('#stop-recording-btn')
    this.retakeBtn = this.el.querySelector('#retake-btn')
    this.confirmBtn = this.el.querySelector('#confirm-btn')
    this.countdown = this.el.querySelector('#countdown')
    this.recordingIndicator = this.el.querySelector('#recording-indicator')
    this.timer = this.el.querySelector('#recording-timer')

    // State
    this.state = 'idle' // idle, previewing, countdown, recording, recorded

    // Bind events
    if (this.startBtn) {
      this.startBtn.addEventListener('click', () => this.startPreview())
    }
    if (this.stopBtn) {
      this.stopBtn.addEventListener('click', () => this.stopRecording())
    }
    if (this.retakeBtn) {
      this.retakeBtn.addEventListener('click', () => this.retake())
    }
    if (this.confirmBtn) {
      this.confirmBtn.addEventListener('click', () => this.confirmRecording())
    }
  },

  async startPreview() {
    try {
      this.stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'user', width: { ideal: 640 }, height: { ideal: 480 } },
        audio: true
      })

      // Hide idle state, show preview
      const idleState = this.el.querySelector('#idle-state')
      if (idleState) idleState.classList.add('hidden')

      if (this.videoPreview) {
        this.videoPreview.srcObject = this.stream
        this.videoPreview.classList.remove('hidden')
      }

      this.state = 'previewing'
      this.pushEvent('preview_started', {})

      // Start countdown after 1 second
      setTimeout(() => this.startCountdown(), 1000)

    } catch (err) {
      console.error('Error accessing camera:', err)
      this.pushEvent('video_error', {message: 'Could not access camera. Please grant permission.'})
    }
  },

  startCountdown() {
    this.state = 'countdown'
    let count = 3

    if (this.countdown) {
      this.countdown.classList.remove('hidden')
      this.countdown.textContent = count
    }

    const countdownInterval = setInterval(() => {
      count--
      if (count > 0) {
        if (this.countdown) this.countdown.textContent = count
      } else {
        clearInterval(countdownInterval)
        if (this.countdown) this.countdown.classList.add('hidden')
        this.startRecording()
      }
    }, 1000)
  },

  startRecording() {
    this.chunks = []
    this.state = 'recording'
    this.recordingStartTime = Date.now()

    // Show recording indicator
    if (this.recordingIndicator) this.recordingIndicator.classList.remove('hidden')
    if (this.stopBtn) this.stopBtn.classList.remove('hidden')
    if (this.startBtn) this.startBtn.classList.add('hidden')

    // Start timer
    this.timerInterval = setInterval(() => {
      const elapsed = Math.floor((Date.now() - this.recordingStartTime) / 1000)
      if (this.timer) {
        this.timer.textContent = `${elapsed}s`
      }
      // Auto-stop after 15 seconds
      if (elapsed >= 15) {
        this.stopRecording()
      }
    }, 100)

    try {
      this.mediaRecorder = new MediaRecorder(this.stream, {
        mimeType: 'video/webm;codecs=vp9,opus'
      })
    } catch (e) {
      // Fallback for browsers that don't support vp9
      this.mediaRecorder = new MediaRecorder(this.stream)
    }

    this.mediaRecorder.ondataavailable = (e) => {
      if (e.data.size > 0) {
        this.chunks.push(e.data)
      }
    }

    this.mediaRecorder.onstop = () => {
      this.videoBlob = new Blob(this.chunks, { type: 'video/webm' })
      this.showPlayback()
    }

    this.mediaRecorder.start(100) // Collect data every 100ms
    this.pushEvent('recording_started', {})
  },

  stopRecording() {
    if (this.timerInterval) {
      clearInterval(this.timerInterval)
    }

    if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
      this.mediaRecorder.stop()
    }

    // Stop stream preview
    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop())
    }

    if (this.recordingIndicator) this.recordingIndicator.classList.add('hidden')
    if (this.stopBtn) this.stopBtn.classList.add('hidden')
  },

  showPlayback() {
    this.state = 'recorded'

    // Hide preview, show playback
    if (this.videoPreview) this.videoPreview.classList.add('hidden')
    const idleState = this.el.querySelector('#idle-state')
    if (idleState) idleState.classList.add('hidden')

    if (this.videoPlayback && this.videoBlob) {
      this.videoPlayback.src = URL.createObjectURL(this.videoBlob)
      this.videoPlayback.classList.remove('hidden')
    }

    // Show playback controls
    const playbackControls = this.el.querySelector('#playback-controls')
    if (playbackControls) playbackControls.classList.remove('hidden')
    if (this.retakeBtn) this.retakeBtn.classList.remove('hidden')
    if (this.confirmBtn) this.confirmBtn.classList.remove('hidden')

    this.pushEvent('recording_complete', {})
  },

  retake() {
    this.state = 'idle'
    this.videoBlob = null
    this.chunks = []

    if (this.videoPlayback) {
      this.videoPlayback.classList.add('hidden')
      URL.revokeObjectURL(this.videoPlayback.src)
    }

    // Hide playback controls
    const playbackControls = this.el.querySelector('#playback-controls')
    if (playbackControls) playbackControls.classList.add('hidden')
    if (this.retakeBtn) this.retakeBtn.classList.add('hidden')
    if (this.confirmBtn) this.confirmBtn.classList.add('hidden')

    // Show idle state
    const idleState = this.el.querySelector('#idle-state')
    if (idleState) idleState.classList.remove('hidden')
    if (this.startBtn) this.startBtn.classList.remove('hidden')

    this.pushEvent('retake', {})
  },

  confirmRecording() {
    if (this.videoBlob) {
      // Convert to base64 for upload (for small files)
      // For larger files, use FormData with direct upload
      const reader = new FileReader()
      reader.onloadend = () => {
        this.pushEvent('video_confirmed', {
          video_data: reader.result,
          size: this.videoBlob.size
        })
      }
      reader.readAsDataURL(this.videoBlob)
    }
  },

  destroyed() {
    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop())
    }
    if (this.timerInterval) {
      clearInterval(this.timerInterval)
    }
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
