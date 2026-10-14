###
  
  Model

###

class window.App.Model extends Spine.Model

  @configure "Model", "id", "product", "version", "type", "properties", "accessory_names"
  
  @hasOne "availability", "App.Availability", "model_id"
  @hasMany "plainAvailabilities", "App.PlainAvailability", "model_id"
  @hasMany "properties", "App.Property"
  @hasMany "items", "App.Item"

  @extend Spine.Model.Ajax
  @extend App.Modules.FindOrBuild

  @url: => "/models"

  name: -> [@product, @version].join(" ").trim()

  # e.g. "Audient ASP-800"; without repeating the manufacturer when the
  # product already starts with it (e.g. "AKG D112")
  nameWithManufacturer: ->
    name = @name()
    manufacturer = (@manufacturer ? "").trim()
    if manufacturer and name.toLowerCase().indexOf(manufacturer.toLowerCase()) != 0
      "#{manufacturer} #{name}"
    else
      name
