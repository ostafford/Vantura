import { Application } from '@hotwired/stimulus'

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
;(window as Window & { Stimulus: Application }).Stimulus = application

export { application }
