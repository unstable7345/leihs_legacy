(() => {
  // NOTE: only for linter and clarity:
  /* global _ */
  /* global _jed */
  const React = window.React

  // A filter like InventoryFilterSelect, but with a checkbox per value to
  // choose several ones. The select only shows what is chosen; a click on it
  // opens the checkboxes instead of its own list.
  window.InventoryFilterMultiSelect = window.createReactClass({
    propTypes: {},

    getInitialState() {
      return { open: false }
    },

    componentDidMount() {
      document.addEventListener('mousedown', this._onDocumentMouseDown)
    },

    componentWillUnmount() {
      document.removeEventListener('mousedown', this._onDocumentMouseDown)
    },

    _onDocumentMouseDown(event) {
      if (this.state.open && this.holder && !this.holder.contains(event.target)) {
        this.setState({ open: false })
      }
    },

    _toggleOpen(event) {
      event.preventDefault()
      this.setState({ open: !this.state.open })
    },

    _toggleValue(value) {
      const selected = this.props.value || []
      this.props.onChange(
        _.contains(selected, value) ? _.without(selected, value) : selected.concat([value])
      )
    },

    _label() {
      const selected = _.filter(this.props.values, (v) => _.contains(this.props.value || [], v.value))
      if (selected.length == 0) {
        return this.props.allLabel
      } else if (selected.length == 1) {
        return selected[0].label
      } else {
        return this.props.severalLabel(selected.length)
      }
    },

    _renderPanel() {
      if (!this.state.open) {
        return null
      }

      return (
        <div
          style={{
            position: 'absolute',
            top: '100%',
            left: 0,
            right: 0,
            zIndex: 1000,
            marginTop: '2px',
            padding: '4px 0',
            background: '#ffffff',
            border: '1px solid rgba(0,0,0,0.25)',
            borderRadius: '4px',
            boxShadow: '0 3px 8px rgba(0,0,0,0.15)',
            maxHeight: '300px',
            overflowY: 'auto'
          }}>
          <a
            onClick={() => this.props.onChange([])}
            style={{ display: 'block', padding: '4px 10px', fontSize: '12px', cursor: 'pointer' }}>
            {this.props.clearLabel || this.props.allLabel}
          </a>
          {this.props.values.map((v) => (
            <label
              key={v.value}
              style={{
                display: 'flex',
                alignItems: 'center',
                padding: '4px 10px',
                fontSize: '12px',
                cursor: 'pointer',
                whiteSpace: 'nowrap'
              }}>
              <input
                type="checkbox"
                checked={_.contains(this.props.value || [], v.value)}
                onChange={() => this._toggleValue(v.value)}
                style={{ marginRight: '6px' }}
              />
              {v.color && (
                <span
                  style={{
                    display: 'inline-block',
                    width: '10px',
                    height: '10px',
                    borderRadius: '5px',
                    background: v.color,
                    marginRight: '6px'
                  }}
                />
              )}
              {v.label}
            </label>
          ))}
        </div>
      )
    },

    render() {
      const label = this._label()
      return (
        <div ref={(el) => (this.holder = el)} style={{ position: 'relative' }}>
          <select
            name={this.props.name}
            value="selection"
            onChange={() => null}
            onMouseDown={this._toggleOpen}
            onKeyDown={(event) => {
              if (_.contains([' ', 'Enter', 'ArrowDown'], event.key)) this._toggleOpen(event)
            }}
            className="width-full">
            <option value="selection">{label}</option>
          </select>
          {this._renderPanel()}
        </div>
      )
    }
  })
})()
