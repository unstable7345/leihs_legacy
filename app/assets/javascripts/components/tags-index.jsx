;(() => {
  // NOTE: only for linter and clarity:
  /* global _jed, $, React */

  const f = window.lodash

  const chipStyle = (color) => ({
    display: 'inline-block',
    padding: '2px 10px',
    borderRadius: '10px',
    backgroundColor: color,
    color: '#ffffff',
    fontWeight: 'bold'
  })

  // The tags of the pool ("Etiquetado", ...): create, rename, recolor, delete
  window.TagsIndex = window.createReactClass({
    propTypes: {},

    getInitialState() {
      return {
        tags: this.props.tags,
        // NOTE: what is typed in a row before saving it, by tag id
        edits: {},
        newName: '',
        error: null
      }
    },

    _request(options, done) {
      this.setState({ error: null })
      $.ajax(
        f.extend({ contentType: 'application/json', dataType: 'json' }, options)
      )
        .done(done)
        .error((res) => {
          this.setState({ error: f.get(res, 'responseJSON.message') || res.statusText })
        })
    },

    _sorted(tags) {
      return f.sortBy(tags, (t) => t.name.toLowerCase())
    },

    _create(event) {
      event.preventDefault()
      const name = this.state.newName.trim()
      if (!name) return
      this._request(
        { url: this.props.create_path, method: 'POST', data: JSON.stringify({ name: name }) },
        (tag) => this.setState({ tags: this._sorted(this.state.tags.concat([tag])), newName: '' })
      )
    },

    _edited(tag) {
      return f.extend({}, tag, this.state.edits[tag.id])
    },

    _edit(tag, attrs) {
      const edits = f.clone(this.state.edits)
      edits[tag.id] = f.extend({}, edits[tag.id], attrs)
      this.setState({ edits: edits })
    },

    _isChanged(tag) {
      const edited = this._edited(tag)
      return edited.name !== tag.name || edited.color !== tag.color
    },

    _save(tag) {
      const edited = this._edited(tag)
      this._request(
        {
          url: this.props.tags_path + '/' + tag.id,
          method: 'PUT',
          data: JSON.stringify({ name: edited.name.trim(), color: edited.color })
        },
        (saved) =>
          this.setState({
            tags: this._sorted(this.state.tags.map((t) => (t.id === saved.id ? saved : t))),
            edits: f.omit(this.state.edits, tag.id)
          })
      )
    },

    _delete(tag) {
      if (!window.confirm(_jed('tags_delete_confirmation', [tag.name, tag.items_count]))) return
      this._request({ url: this.props.tags_path + '/' + tag.id, method: 'DELETE', dataType: 'text' }, () =>
        this.setState({
          tags: f.reject(this.state.tags, (t) => t.id === tag.id),
          edits: f.omit(this.state.edits, tag.id)
        })
      )
    },

    _renderRow(tag) {
      const edited = this._edited(tag)
      return (
        <div key={tag.id} className="line row focus-hover-thin" data-id={tag.id} data-type="tag">
          <div className="col1of5 line-col">
            <span style={chipStyle(edited.color)}>{edited.name || '…'}</span>
          </div>
          <div className="col2of5 line-col text-align-left">
            <input
              type="color"
              value={edited.color}
              onChange={(event) => this._edit(tag, { color: event.target.value })}
              title={_jed('Color')}
              style={{ width: '40px', height: '30px', padding: 0, marginRight: '8px', verticalAlign: 'middle' }}
            />
            <input
              type="text"
              value={edited.name}
              onChange={(event) => this._edit(tag, { name: event.target.value })}
              onKeyDown={(event) => {
                if (event.key === 'Enter' && this._isChanged(tag)) this._save(tag)
              }}
              maxLength={40}
              autoComplete="off"
              style={{ width: '60%', verticalAlign: 'middle', fontSize: '14px' }}
            />
          </div>
          <div className="col1of5 line-col text-align-center">
            {_jed('Items')}: {tag.items_count}
          </div>
          <div className="col1of5 line-col line-actions padding-right-xs text-align-right">
            <button
              type="button"
              className="button green"
              disabled={!this._isChanged(tag)}
              onClick={() => this._save(tag)}>
              {_jed('Save')}
            </button>{' '}
            <button type="button" className="button white" onClick={() => this._delete(tag)}>
              <i className="fa fa-trash" /> {_jed('Delete')}
            </button>
          </div>
        </div>
      )
    },

    render() {
      return (
        <div className="row content-wrapper min-height-xl min-width-full straight-top">
          <div className="margin-top-l padding-horizontal-m">
            <div className="row">
              <h1 className="headline-xl">{_jed('Tags')}</h1>
              <p className="paragraph-s margin-top-s">{_jed('tags_explanation')}</p>
            </div>
          </div>

          <form className="row margin-top-m padding-horizontal-m" onSubmit={this._create}>
            <input
              type="text"
              name="new_tag_name"
              value={this.state.newName}
              placeholder={_jed('New tag')}
              onChange={(event) => this.setState({ newName: event.target.value })}
              maxLength={40}
              autoComplete="off"
              style={{ width: '300px', marginRight: '8px' }}
            />
            <button type="submit" className="button white">
              {_jed('Add')}
            </button>
          </form>

          {this.state.error && (
            <p className="emboss red padding-inset-s margin-top-s margin-horizontal-m text-align-center">
              {this.state.error}
            </p>
          )}

          <div className="list-of-lines even margin-top-m">
            {this.state.tags.map(this._renderRow)}
          </div>
        </div>
      )
    }
  })

  window.TagsIndex.displayName = 'TagsIndex'
})()
