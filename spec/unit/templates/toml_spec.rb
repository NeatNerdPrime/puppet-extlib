# frozen_string_literal: true

require 'spec_helper'

describe 'test_toml', type: :class do
  let(:pre_condition) do
    <<~PUPPET
      class test_toml (
        Optional[Variant[String, Array[String]]] $comments = undef,
      ) {
        $content = epp('extlib/toml.epp', {
          'data'     => {
            'b' => { 'y' => 2, 'x' => 1 },
            'a' => 1,
          },
          'comments' => $comments,
        })

        file { '/tmp/test-toml':
          ensure  => file,
          content => $content,
        }

        $sensitive_content = epp('extlib/toml.epp', {
          'data' => { 'password' => Sensitive('secret') },
        })

        file { '/tmp/test-toml-sensitive':
          ensure  => file,
          content => $sensitive_content,
        }
      }
    PUPPET
  end

  context 'with default comments' do
    it 'renders the default header and sorted TOML' do
      is_expected.to contain_file('/tmp/test-toml').with_content(<<~TOML)
        # This file is managed with puppet
        #
        a = 1
        [b]
        x = 1
        y = 2
      TOML
    end
  end

  context 'with custom comments' do
    let(:params) { { 'comments' => ['comment one', 'comment two'] } }

    it 'renders the default header, custom comments, and sorted TOML' do
      is_expected.to contain_file('/tmp/test-toml').with_content(<<~TOML)
        # This file is managed with puppet
        #
        # comment one
        # comment two
        #
        a = 1
        [b]
        x = 1
        y = 2
      TOML
    end
  end

  context 'with a single string comment' do
    let(:params) { { 'comments' => 'single comment' } }

    it 'renders the string as one comment' do
      is_expected.to contain_file('/tmp/test-toml').with_content(<<~TOML)
        # This file is managed with puppet
        #
        # single comment
        #
        a = 1
        [b]
        x = 1
        y = 2
      TOML
    end
  end

  context 'with sensitive values' do
    it 'renders sensitive values as plain text' do
      is_expected.to contain_file('/tmp/test-toml-sensitive').with_content(<<~TOML)
        # This file is managed with puppet
        #
        password = "secret"
      TOML
    end
  end
end
