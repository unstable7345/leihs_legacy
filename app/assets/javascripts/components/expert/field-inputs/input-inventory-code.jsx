;(() => {
  // NOTE: only for linter and clarity:
  /* global _jed, React, PropTypes, RenderFieldLabel, InputText */

  window.InputInventoryCode = window.createReactClass({
    propTypes: {},
    contextTypes: {
      isBatchCreate: PropTypes.bool,
      batchCreateInventoryCodePrefix: PropTypes.string,
      codePattern: PropTypes.object,
      codePatternPreview: PropTypes.object,
      onCodePatternChange: PropTypes.func,
      batchCreateItemFieldsDisabled: PropTypes.arrayOf(PropTypes.string.isRequired)
    },

    getInitialState() {
      return {
        selected: 'plusOne'
      }
    },

    _plusOne(event) {
      event.preventDefault()
      this.setState({ selected: 'plusOne' })
      var l = window.lodash
      var value = l.cloneDeep(this.props.selectedValue.value)
      value.text = this.props.inventoryCodeProps.next_code
      this.props.onChange(value)
    },

    _fillGap(event) {
      event.preventDefault()
      this.setState({ selected: 'fillGap' })
      var l = window.lodash
      var value = l.cloneDeep(this.props.selectedValue.value)
      value.text = this.props.inventoryCodeProps.lowest_code
      this.props.onChange(value)
    },

    _maximum(event) {
      event.preventDefault()
      this.setState({ selected: 'maximum' })
      var l = window.lodash
      var value = l.cloneDeep(this.props.selectedValue.value)
      value.text = this.props.inventoryCodeProps.highest_code
      this.props.onChange(value)
    },

    _renderPlusOne() {
      return null
    },

    _renderFillGap() {
      return null
    },

    _renderMaximum() {
      return null
    },

    _renderButtons() {
      if (this.props.editMode) {
        return null
      }

      return (
        <div className="row text-align-right margin-top-xs" id="switch">
          <button
            type="button"
            onClick={this._plusOne}
            className={'button small ' + (this.state.selected == 'plusOne' ? 'green' : 'white')}>
            {' ' + _jed('last used +1') + ' '}
          </button>{' '}
          <button
            type="button"
            onClick={this._fillGap}
            className={'button small ' + (this.state.selected == 'fillGap' ? 'green' : 'white')}>
            {' ' + _jed('fill up gaps') + ' '}
          </button>{' '}
          <button
            type="button"
            onClick={this._maximum}
            className={'button small ' + (this.state.selected == 'maximum' ? 'green' : 'white')}>
            {' ' + _jed('assign highest available') + ' '}
          </button>
        </div>
      )
    },

    _changeCodePattern(key, value) {
      const codePattern = window.lodash.cloneDeep(this.context.codePattern)
      window.lodash.set(codePattern, key, value)
      this.context.onCodePatternChange(codePattern)
    },

    _renderCodePatternPreview() {
      const preview = this.context.codePatternPreview
      if (!preview) {
        return null
      } else if (preview.error) {
        return <p className="font-size-s margin-top-xs red">{preview.error}</p>
      } else {
        return (
          <p className="font-size-s margin-top-xs" id="code-pattern-preview">
            <strong>{_jed('create_multiple_items_code_preview')}:</strong>{' '}
            {preview.first === preview.last ? preview.first : preview.first + ' … ' + preview.last}
          </p>
        )
      }
    },

    _renderCodePattern() {
      const codePattern = this.context.codePattern
      // NOTE: no spaces in codes
      const noSpaces = (value) => value.replace(/\s/g, '')
      const inputStyle = { width: '5.5em', marginRight: '4px' }

      return (
        <div className="row margin-top-xs" id="code-pattern">
          <div className="col1of2 padding-vertical-xs">
            {_jed('create_multiple_items_code_parts')}
          </div>
          <div className="col1of2">
            {codePattern.parts.map((part, i) => (
              <input
                key={i}
                type="text"
                name={'code_pattern[parts][' + i + ']'}
                value={part}
                placeholder={['MIC', 'TLM', ''][i]}
                onChange={({ target: { value } }) =>
                  this._changeCodePattern(['parts', i], noSpaces(value))
                }
                style={inputStyle}
                maxLength={20}
                autoComplete="off"
              />
            ))}
          </div>
          <div className="col1of2 padding-vertical-xs">
            {_jed('create_multiple_items_code_separator')}
          </div>
          <div className="col1of2 padding-vertical-xxs">
            <input
              type="text"
              name="code_pattern[separator]"
              value={codePattern.separator}
              onChange={({ target: { value } }) =>
                this._changeCodePattern('separator', noSpaces(value))
              }
              style={inputStyle}
              maxLength={3}
              autoComplete="off"
            />
          </div>
          <div className="col1of2 padding-vertical-xs">
            {_jed('create_multiple_items_code_digits')}
          </div>
          <div className="col1of2">
            <select
              name="code_pattern[digits]"
              value={codePattern.digits}
              onChange={({ target: { value } }) =>
                this._changeCodePattern('digits', parseInt(value, 10))
              }
              style={inputStyle}>
              {[1, 2, 3, 4, 5, 6].map((n) => (
                <option key={n} value={n}>
                  {window.lodash.padStart('1', n, '0')}
                </option>
              ))}
            </select>
          </div>
        </div>
      )
    },

    render() {
      const props = this.props
      const selectedValue = props.selectedValue

      var fieldClass = 'field row emboss padding-inset-xs margin-vertical-xxs margin-right-xs'
      if (this.props.error) {
        fieldClass += ' error'
      }
      if (selectedValue.hidden) {
        fieldClass += ' hidden'
      }

      if (this.context.isBatchCreate) {
        return (
          <div className={fieldClass} data-editable="false" data-required="false" data-type="field">
            <div className="row">
              {RenderFieldLabel._renderFieldLabel(selectedValue.field, this.props.onClose, true)}
              <div className="col1of2" data-type="value">
                <input
                  type="text"
                  className="width-full"
                  disabled
                  readOnly
                  value={
                    window.lodash.some(this.context.codePattern.parts)
                      ? window.lodash
                          .compact(this.context.codePattern.parts)
                          .concat(window.lodash.repeat('#', this.context.codePattern.digits))
                          .join(this.context.codePattern.separator)
                      : this.context.batchCreateInventoryCodePrefix + '…'
                  }
                />
              </div>
            </div>
            {this._renderCodePattern()}
            {this._renderCodePatternPreview()}
            <p className="font-size-s margin-top-xs">
              {window.lodash.some(this.context.codePattern.parts)
                ? _jed('create_multiple_items_code_pattern_notice')
                : _jed('create_multiple_items_inv_code_notice')}
            </p>
          </div>
        )
      }

      return (
        <div
          className={fieldClass}
          data-editable="true"
          data-id="inventory_code"
          data-required="true"
          data-type="field">
          <div className="row">
            {RenderFieldLabel._renderFieldLabel(selectedValue.field, this.props.onClose, true)}
            <InputText selectedValue={selectedValue} onChange={this.props.onChange} />
          </div>
          {this._renderButtons()}
        </div>
      )
    }
  })
})()
