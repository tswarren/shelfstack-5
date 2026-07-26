# frozen_string_literal: true

# Inline SVG icons from a vendored Phosphor subset (MIT).
# Source: Phosphor Icons Regular — https://phosphoricons.com/
# Only allowlisted names may be rendered; unknown names raise ArgumentError.
module IconsHelper
  # name => [viewBox, path_d]
  ICONS = {
    "info" => [
      "0 0 256 256",
      "M128,24A104,104,0,1,0,232,128,104.11,104.11,0,0,0,128,24Zm0,192a88,88,0,1,1,88-88A88.1,88.1,0,0,1,128,216Zm16-40a8,8,0,0,1-8,8,16,16,0,0,1-16-16V128a8,8,0,0,1,0-16,16,16,0,0,1,16,16v40A8,8,0,0,1,144,176ZM112,84a12,12,0,1,1,12,12A12,12,0,0,1,112,84Z"
    ],
    "caret-right" => [
      "0 0 256 256",
      "M181.66,133.66l-80,80a8,8,0,0,1-11.32-11.32L164.69,128,90.34,53.66a8,8,0,0,1,11.32-11.32l80,80A8,8,0,0,1,181.66,133.66Z"
    ],
    "warning-circle" => [
      "0 0 256 256",
      "M128,24A104,104,0,1,0,232,128,104.11,104.11,0,0,0,128,24Zm0,192a88,88,0,1,1,88-88A88.1,88.1,0,0,1,128,216Zm-8-40a8,8,0,0,1,16,0v8a8,8,0,0,1-16,0Zm8-104a8,8,0,0,0-8,8v56a8,8,0,0,0,16,0V80A8,8,0,0,0,128,72Z"
    ]
  }.freeze

  # Renders an allowlisted inline SVG icon.
  # Decorative by default (aria-hidden). Pass title: for a labelled icon.
  def icon_tag(name, title: nil, **html_options)
    key = name.to_s
    definition = ICONS[key]
    raise ArgumentError, "Unknown icon: #{name.inspect}" unless definition

    view_box, path_d = definition
    css_class = [ "icon", "icon-#{key}", html_options.delete(:class) ].compact.join(" ")
    width = html_options.delete(:width) || 16
    height = html_options.delete(:height) || 16
    attrs = html_options.merge(
      class: css_class,
      viewBox: view_box,
      fill: "currentColor",
      width: width,
      height: height,
      focusable: "false"
    )

    if title.present?
      attrs[:role] = "img"
      attrs["aria-label"] = title
    else
      attrs["aria-hidden"] = "true"
    end

    tag.svg(**attrs) do
      tag.path(d: path_d)
    end
  end
end
