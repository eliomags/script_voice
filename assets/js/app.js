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
    this.selectedCamera = null
    this.selectedMic = null
    this.audioContext = null
    this.audioAnalyser = null
    this.audioLevelInterval = null

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
      } else if (target.id === 'settings-btn') {
        e.preventDefault()
        this.toggleSettings()
      }
    })

    // Handle device selection changes
    this.el.addEventListener('change', (e) => {
      if (e.target.id === 'camera-select') {
        this.selectedCamera = e.target.value
      } else if (e.target.id === 'mic-select') {
        this.selectedMic = e.target.value
        // Restart audio monitoring with new mic
        this.stopAudioLevelMonitor()
        this.startSettingsAudioMonitor()
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
      playbackControls: this.el.querySelector('#playback-controls'),
      settingsPanel: this.el.querySelector('#settings-panel'),
      settingsChevron: this.el.querySelector('#settings-chevron'),
      cameraSelect: this.el.querySelector('#camera-select'),
      micSelect: this.el.querySelector('#mic-select'),
      audioLevel: this.el.querySelector('#audio-level')
    }
  },

  async toggleSettings() {
    const els = this.getElements()
    const isOpen = els.settingsPanel && !els.settingsPanel.classList.contains('hidden')

    if (isOpen) {
      // Close settings
      if (els.settingsPanel) els.settingsPanel.classList.add('hidden')
      if (els.settingsChevron) els.settingsChevron.classList.remove('rotate-180')
      this.stopAudioLevelMonitor()
    } else {
      // Open settings

      // First, request permission to access devices (needed to get device labels)
      try {
        const tempStream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true })
        tempStream.getTracks().forEach(track => track.stop())
      } catch (err) {
        console.warn('Could not get permission for device enumeration')
      }

      // Enumerate devices
      const devices = await navigator.mediaDevices.enumerateDevices()
      const cameras = devices.filter(d => d.kind === 'videoinput')
      const mics = devices.filter(d => d.kind === 'audioinput')

      // Populate camera dropdown
      if (els.cameraSelect) {
        els.cameraSelect.innerHTML = cameras.map((cam, i) =>
          `<option value="${cam.deviceId}" ${cam.deviceId === this.selectedCamera ? 'selected' : ''}>
            ${cam.label || `Camera ${i + 1}`}
          </option>`
        ).join('')
        if (!this.selectedCamera && cameras.length > 0) {
          this.selectedCamera = cameras[0].deviceId
        }
      }

      // Populate mic dropdown
      if (els.micSelect) {
        els.micSelect.innerHTML = mics.map((mic, i) =>
          `<option value="${mic.deviceId}" ${mic.deviceId === this.selectedMic ? 'selected' : ''}>
            ${mic.label || `Microphone ${i + 1}`}
          </option>`
        ).join('')
        if (!this.selectedMic && mics.length > 0) {
          this.selectedMic = mics[0].deviceId
        }
      }

      // Show settings panel and rotate chevron
      if (els.settingsPanel) els.settingsPanel.classList.remove('hidden')
      if (els.settingsChevron) els.settingsChevron.classList.add('rotate-180')

      // Start audio monitoring for level indicator
      await this.startSettingsAudioMonitor()
    }
  },

  async startSettingsAudioMonitor() {
    // Get a temporary audio stream just for level monitoring
    try {
      const constraints = {
        audio: this.selectedMic ? { deviceId: { exact: this.selectedMic } } : true,
        video: false
      }
      this.settingsStream = await navigator.mediaDevices.getUserMedia(constraints)
      this.setupAudioAnalyser(this.settingsStream)
      this.startAudioLevelMonitor()
    } catch (err) {
      console.warn('Could not start audio monitoring:', err)
    }
  },

  async updatePreviewStream() {
    const els = this.getElements()

    // Stop existing stream
    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop())
    }

    try {
      const constraints = {
        video: this.selectedCamera
          ? { deviceId: { exact: this.selectedCamera }, width: { ideal: 640 }, height: { ideal: 480 } }
          : { facingMode: 'user', width: { ideal: 640 }, height: { ideal: 480 } },
        audio: this.selectedMic
          ? { deviceId: { exact: this.selectedMic } }
          : true
      }

      this.stream = await navigator.mediaDevices.getUserMedia(constraints)

      if (els.videoPreview) {
        els.videoPreview.srcObject = this.stream
        els.videoPreview.classList.remove('hidden')
        await els.videoPreview.play()
      }

      // Update audio analyser
      this.setupAudioAnalyser()

    } catch (err) {
      console.error('Error updating stream:', err)
    }
  },

  setupAudioAnalyser(stream) {
    const audioStream = stream || this.stream
    if (!audioStream) return

    const audioTrack = audioStream.getAudioTracks()[0]
    if (!audioTrack) return

    if (!this.audioContext) {
      this.audioContext = new (window.AudioContext || window.webkitAudioContext)()
    }

    const source = this.audioContext.createMediaStreamSource(audioStream)
    this.audioAnalyser = this.audioContext.createAnalyser()
    this.audioAnalyser.fftSize = 256
    source.connect(this.audioAnalyser)
  },

  startAudioLevelMonitor() {
    const els = this.getElements()
    if (!els.audioLevel) return

    this.audioLevelInterval = setInterval(() => {
      if (!this.audioAnalyser) return

      const dataArray = new Uint8Array(this.audioAnalyser.frequencyBinCount)
      this.audioAnalyser.getByteFrequencyData(dataArray)

      // Calculate average volume
      const average = dataArray.reduce((a, b) => a + b, 0) / dataArray.length
      const percentage = Math.min(100, (average / 128) * 100)

      els.audioLevel.style.width = `${percentage}%`
    }, 50)
  },

  stopAudioLevelMonitor() {
    if (this.audioLevelInterval) {
      clearInterval(this.audioLevelInterval)
      this.audioLevelInterval = null
    }
    // Stop settings audio stream if exists
    if (this.settingsStream) {
      this.settingsStream.getTracks().forEach(track => track.stop())
      this.settingsStream = null
    }
  },

  async startPreview() {
    const els = this.getElements()

    try {
      const constraints = {
        video: this.selectedCamera
          ? { deviceId: { exact: this.selectedCamera }, width: { ideal: 640 }, height: { ideal: 480 } }
          : { facingMode: 'user', width: { ideal: 640 }, height: { ideal: 480 } },
        audio: this.selectedMic
          ? { deviceId: { exact: this.selectedMic } }
          : true
      }

      this.stream = await navigator.mediaDevices.getUserMedia(constraints)

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
      // Auto-stop after 10 seconds (enough to read the verification phrase)
      if (elapsed >= 10) {
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

    // Show playback controls AND the buttons inside
    if (els.playbackControls) els.playbackControls.classList.remove('hidden')
    if (els.retakeBtn) els.retakeBtn.classList.remove('hidden')
    if (els.confirmBtn) els.confirmBtn.classList.remove('hidden')
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
    if (this.settingsStream) {
      this.settingsStream.getTracks().forEach(track => track.stop())
    }
    if (this.timerInterval) {
      clearInterval(this.timerInterval)
    }
    this.stopAudioLevelMonitor()
    if (this.audioContext) {
      this.audioContext.close()
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

// Bible file reader - reads file client-side and sends content to server
Hooks.BibleFileReader = {
  mounted() {
    const fileInput = this.el.querySelector('input[type="file"]')
    if (!fileInput) return

    // Handle file selection
    fileInput.addEventListener('change', (e) => {
      const file = e.target.files[0]
      if (!file) return
      this.readAndSendFile(file)
    })

    // Handle drag and drop
    this.el.addEventListener('dragover', (e) => {
      e.preventDefault()
      this.el.classList.add('border-purple-400', 'bg-purple-50')
    })

    this.el.addEventListener('dragleave', (e) => {
      e.preventDefault()
      this.el.classList.remove('border-purple-400', 'bg-purple-50')
    })

    this.el.addEventListener('drop', (e) => {
      e.preventDefault()
      this.el.classList.remove('border-purple-400', 'bg-purple-50')
      const file = e.dataTransfer.files[0]
      if (file && (file.name.endsWith('.txt') || file.name.endsWith('.pdf'))) {
        this.readAndSendFile(file)
      }
    })
  },

  readAndSendFile(file) {
    // Show loading state
    const label = this.el.querySelector('label')
    if (label) {
      label.innerHTML = `<span class="text-purple-600 animate-pulse">Reading ${file.name}...</span>`
    }

    const reader = new FileReader()
    reader.onload = (e) => {
      const content = e.target.result
      this.pushEvent('import_bible_content', {
        content: content,
        filename: file.name
      })
    }
    reader.onerror = () => {
      if (label) {
        label.innerHTML = `<span class="text-red-500">Error reading file</span>`
      }
    }
    reader.readAsText(file)
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
