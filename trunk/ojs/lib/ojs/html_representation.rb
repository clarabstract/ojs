module OJS
  # As the name implies, this module generates html "representations" for an object (usually a model, but not neccessarily 
  # so - they can also just be used "on their own" to represent any sort of UI structure that is meaningless to the app itself)
  #
  # A more apprioriate name is really "view" but this is already spoken for by default Rails views ;)
  # 
  # Representations basically associate a snippet of html with some object, mapping attributes to specific elements (not unlike
  # the form_for family of ActionView helper methods). 
  # 
  # In addition to this, they automatically assign apporipate html IDs, names that are meant to work with event_dispatcher.js 
  # (and also attach non-propagating events directly - like onsubmit for forms)
  # 
  module HtmlRepresentation
  end
end