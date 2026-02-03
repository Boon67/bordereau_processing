import React from 'react'
import { Select } from 'antd'
import { SearchOutlined } from '@ant-design/icons'
import type { TPA } from '../types'

interface TPASelectorProps {
  value: string
  onChange: (value: string) => void
  tpas: TPA[]
  placeholder?: string
  style?: React.CSSProperties
  mode?: 'single' | 'multiple'
}

const TPASelector: React.FC<TPASelectorProps> = ({
  value,
  onChange,
  tpas,
  placeholder = 'All TPAs',
  style = { width: 300 },
  mode = 'single'
}) => {
  const sortedTpas = [...tpas].sort((a, b) => a.TPA_NAME.localeCompare(b.TPA_NAME))

  return (
    <Select
      value={value}
      onChange={onChange}
      style={style}
      placeholder={placeholder}
      showSearch
      suffixIcon={<SearchOutlined />}
      filterOption={(input, option) =>
        (option?.label ?? '').toLowerCase().includes(input.toLowerCase())
      }
      options={sortedTpas.map(tpa => ({
        value: tpa.TPA_CODE,
        label: tpa.TPA_NAME,
      }))}
      allowClear={mode === 'single'}
    />
  )
}

export default TPASelector
