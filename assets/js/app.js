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
    this.state = 'idle' // idle, previewing, countdown, recording, recorded

    // Bind events using event delegation on the container
    this.el.addEventListener('click', (e) => {
      const target = e.target.closest('button')
      if (!target) return

      if (target.id === 'start-recording-btn') {
        e.preventDefault()
        this.startPreview()
      } else if (target.id === 'stop-recording-btn') {
        e.preventDefault()
        this.stopRecording()
      } else if (target.id === 'retake-btn') {
        e.preventDefault()
        this.retake()
      } else if (target.id === 'confirm-btn') {
        e.preventDefault()
        this.confirmRecording()
      }
    })
  },

  // Helper to get fresh DOM references
  getElements() {
    return {
      videoPreview: this.el.querySelector('#video-preview'),
      videoPlayback: this.el.querySelector('#video-playback'),
      startBtn: this.el.querySelector('#start-recording-btn'),
      stopBtn: this.el.querySelector('#stop-recording-btn'),
      retakeBtn: this.el.querySelector('#retake-btn'),
      confirmBtn: this.el.querySelector('#confirm-btn'),
      countdown: this.el.querySelector('#countdown'),
      recordingIndicator: this.el.querySelector('#recording-indicator'),
      timer: this.el.querySelector('#recording-timer'),
      idleState: this.el.querySelector('#idle-state'),
      playbackControls: this.el.querySelector('#playback-controls')
    }
  },

  async startPreview() {
    const els = this.getElements()

    try {
      this.stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'user', width: { ideal: 640 }, height: { ideal: 480 } },
        audio: true
      })

      // Hide idle state, show preview
      if (els.idleState) els.idleState.classList.add('hidden')

      if (els.videoPreview) {
        els.videoPreview.srcObject = this.stream
        els.videoPreview.classList.remove('hidden')
        // Explicitly play the video (required by some browsers)
        try {
          await els.videoPreview.play()
        } catch (playErr) {
          console.warn('Autoplay blocked, user interaction needed:', playErr)
        }
      }

      this.state = 'previewing'
      // Don't push event here - the area has phx-update="ignore"

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
    const els = this.getElements()

    if (els.countdown) {
      els.countdown.classList.remove('hidden')
      els.countdown.textContent = count
    }

    const countdownInterval = setInterval(() => {
      count--
      const currentEls = this.getElements()
      if (count > 0) {
        if (currentEls.countdown) currentEls.countdown.textContent = count
      } else {
        clearInterval(countdownInterval)
        if (currentEls.countdown) currentEls.countdown.classList.add('hidden')
        this.startRecording()
      }
    }, 1000)
  },

  startRecording() {
    const els = this.getElements()
    this.chunks = []
    this.state = 'recording'
    this.recordingStartTime = Date.now()

    // Show recording indicator
    if (els.recordingIndicator) els.recordingIndicator.classList.remove('hidden')
    if (els.stopBtn) els.stopBtn.classList.remove('hidden')
    if (els.startBtn) els.startBtn.classList.add('hidden')

    // Start timer
    this.timerInterval = setInterval(() => {
      const elapsed = Math.floor((Date.now() - this.recordingStartTime) / 1000)
      const currentEls = this.getElements()
      if (currentEls.timer) {
        currentEls.timer.textContent = `${elapsed}s`
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
    // Don't push event - area has phx-update="ignore"
  },

  stopRecording() {
    const els = this.getElements()

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

    if (els.recordingIndicator) els.recordingIndicator.classList.add('hidden')
    if (els.stopBtn) els.stopBtn.classList.add('hidden')
  },

  showPlayback() {
    const els = this.getElements()
    this.state = 'recorded'

    // Hide preview, show playback
    if (els.videoPreview) els.videoPreview.classList.add('hidden')
    if (els.idleState) els.idleState.classList.add('hidden')

    if (els.videoPlayback && this.videoBlob) {
      els.videoPlayback.src = URL.createObjectURL(this.videoBlob)
      els.videoPlayback.classList.remove('hidden')
    }

    // Show playback controls
    if (els.playbackControls) els.playbackControls.classList.remove('hidden')
    // Don't push event - area has phx-update="ignore"
  },

  retake() {
    const els = this.getElements()
    this.state = 'idle'
    this.videoBlob = null
    this.chunks = []

    if (els.videoPlayback) {
      els.videoPlayback.classList.add('hidden')
      if (els.videoPlayback.src) {
        URL.revokeObjectURL(els.videoPlayback.src)
      }
    }

    // Hide playback controls
    if (els.playbackControls) els.playbackControls.classList.add('hidden')
    if (els.retakeBtn) els.retakeBtn.classList.add('hidden')
    if (els.confirmBtn) els.confirmBtn.classList.add('hidden')

    // Show idle state
    if (els.idleState) els.idleState.classList.remove('hidden')
    if (els.startBtn) els.startBtn.classList.remove('hidden')
    // Don't push event - area has phx-update="ignore"
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
