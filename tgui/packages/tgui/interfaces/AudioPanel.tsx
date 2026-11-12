import {
  Box,
  Button,
  Dropdown,
  LabeledList,
  NumberInput,
  Section,
  Slider,
  Stack,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type AudioField = {
  index: number;
  label: string;
  group: string;
  min: number;
  max: number;
  step: number;
  value: number;
  unit?: string;
};

type AudioFlag = {
  name: string;
  bit: number;
  enabled: boolean;
};

type Data = {
  soundFile: string;
  volume: number;
  soundX: number;
  soundY: number;
  soundZ: number;
  loop: boolean;
  environmentEnabled: boolean;
  environmentPreset: string;
  environmentPresets: string[];
  environmentFields: AudioField[];
  environmentFlags: AudioFlag[];
  echoFields: AudioField[];
  echoFlags: AudioFlag[];
};

const environmentGroups = [
  'Room',
  'Decay',
  'Reflections and reverb',
  'Echo and modulation',
  'Other',
];

const echoGroups = [
  'Direct and room',
  'Obstruction and occlusion',
  'Exclusion and outside volume',
  'Distance and air absorption',
];

function ParameterFields(props: {
  fields: AudioField[];
  groups: string[];
  disabled?: boolean;
  action: string;
}) {
  const { act } = useBackend();
  const { fields, groups, disabled, action } = props;

  return groups.map((group) => {
    const groupFields = fields.filter((field) => field.group === group);
    return (
      <Section key={group} title={group}>
        <LabeledList>
          {groupFields.map((field) => (
            <LabeledList.Item key={field.index} label={field.label}>
              <NumberInput
                width="90px"
                value={field.value}
                minValue={field.min}
                maxValue={field.max}
                step={field.step}
                stepPixelSize={5}
                unit={field.unit}
                disabled={disabled}
                onChange={(value) =>
                  act(action, {
                    index: field.index,
                    value,
                  })
                }
              />
            </LabeledList.Item>
          ))}
        </LabeledList>
      </Section>
    );
  });
}

function FlagFields(props: {
  flags: AudioFlag[];
  action: string;
  disabled?: boolean;
}) {
  const { act } = useBackend();
  const { flags, action, disabled } = props;

  return (
    <Stack vertical>
      {flags.map((flag) => (
        <Stack.Item key={flag.bit}>
          <Button.Checkbox
            checked={flag.enabled}
            disabled={disabled}
            onClick={() => act(action, { bit: flag.bit })}
          >
            {flag.name}
          </Button.Checkbox>
        </Stack.Item>
      ))}
    </Stack>
  );
}

export function AudioPanel() {
  const { act, data } = useBackend<Data>();
  const {
    soundFile,
    volume,
    soundX,
    soundY,
    soundZ,
    loop,
    environmentEnabled,
    environmentPreset,
    environmentPresets = [],
    environmentFields = [],
    environmentFlags = [],
    echoFields = [],
    echoFlags = [],
  } = data;

  return (
    <Window title="Audio Panel" width={1120} height={900} resizable theme="admin">
      <Window.Content>
        <Stack fill vertical>
          <Stack.Item grow>
            <Box style={{ height: '100%', overflowY: 'auto', paddingRight: '0.5rem' }}>
              <Section title="Preview source">
                <Stack align="center">
                  <Stack.Item grow>
                    <Box bold>{soundFile}</Box>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      icon="folder-open"
                      onClick={() => act('choose_sound')}
                    >
                      Choose audio file...
                    </Button>
                  </Stack.Item>
                </Stack>
                <Stack fill align="center" mt={1}>
                  <Stack.Item>
                    <Box>Volume</Box>
                  </Stack.Item>
                  <Stack.Item grow={1} mx={1}>
                    <Slider
                      value={volume}
                      minValue={0}
                      maxValue={100}
                      step={1}
                      unit="%"
                      stepPixelSize={1}
                      onChange={(_event, value) =>
                        act('set_volume', { value })
                      }
                    />
                  </Stack.Item>
                  <Stack.Item>
                    <Button.Checkbox
                      checked={loop}
                      onClick={() => act('toggle_loop')}
                    >
                      Loop
                    </Button.Checkbox>
                  </Stack.Item>
                </Stack>
                <Stack fill align="center" mt={1}>
                  <Stack.Item>
                    <Box>Sound position</Box>
                  </Stack.Item>
                  <Stack.Item>
                    <Box inline bold mr={0.5}>
                      X
                    </Box>
                    <NumberInput
                      width="55px"
                      value={soundX}
                      minValue={-127}
                      maxValue={127}
                      step={1}
                      onChange={(value) =>
                        act('set_position', { axis: 'x', value })
                      }
                    />
                  </Stack.Item>
                  <Stack.Item>
                    <Box inline bold mr={0.5}>
                      Y
                    </Box>
                    <NumberInput
                      width="55px"
                      value={soundY}
                      minValue={-127}
                      maxValue={127}
                      step={1}
                      onChange={(value) =>
                        act('set_position', { axis: 'y', value })
                      }
                    />
                  </Stack.Item>
                  <Stack.Item>
                    <Box inline bold mr={0.5}>
                      Z
                    </Box>
                    <NumberInput
                      width="55px"
                      value={soundZ}
                      minValue={-127}
                      maxValue={127}
                      step={1}
                      onChange={(value) =>
                        act('set_position', { axis: 'z', value })
                      }
                    />
                  </Stack.Item>
                </Stack>
              </Section>

              <Box
                style={{
                  display: 'grid',
                  gridTemplateColumns: 'minmax(0, 1fr) minmax(0, 1fr)',
                  gap: '0.5rem',
                  alignItems: 'start',
                }}
              >
                <Section title="Sound environment">
                  <LabeledList>
                    <LabeledList.Item label="Preset">
                      <Dropdown
                        fluid
                        selected={environmentPreset}
                        options={environmentPresets}
                        onSelected={(value) =>
                          act('set_environment_preset', { value })
                        }
                      />
                    </LabeledList.Item>
                  </LabeledList>
                  <Box color="label" mt={1} mb={1}>
                    Environment and echo are applied to this world-space preview.
                    With Loop enabled, edits update the running preview. Otherwise,
                    press Play to hear the current settings.
                  </Box>
                  <Box
                    style={{
                      maxHeight: '610px',
                      overflowY: 'auto',
                      paddingRight: '0.4rem',
                    }}
                  >
                    <ParameterFields
                      fields={environmentFields}
                      groups={environmentGroups}
                      disabled={!environmentEnabled}
                      action="set_environment_field"
                    />
                    <Section title="Environment flag switches">
                      <FlagFields
                        flags={environmentFlags}
                        action="toggle_environment_flag"
                        disabled={!environmentEnabled}
                      />
                    </Section>
                  </Box>
                </Section>

                <Section
                  title="Echo"
                  buttons={
                    <Button icon="sync" onClick={() => act('reset_echo')}>
                      Reset defaults
                    </Button>
                  }
                >
                  <Box color="label" mb={1}>
                    These 18 values are BYOND's per-sound EAX echo settings.
                  </Box>
                  <Box
                    style={{
                      maxHeight: '610px',
                      overflowY: 'auto',
                      paddingRight: '0.4rem',
                    }}
                  >
                    <ParameterFields
                      fields={echoFields}
                      groups={echoGroups}
                      action="set_echo_field"
                    />
                    <Section title="Echo flag switches">
                      <FlagFields
                        flags={echoFlags}
                        action="toggle_echo_flag"
                      />
                    </Section>
                  </Box>
                </Section>
              </Box>
            </Box>
          </Stack.Item>

          <Stack.Item>
            <Stack align="center">
              <Stack.Item>
                <Button
                  icon="play"
                  color="green"
                  onClick={() => act('play')}
                >
                  Play
                </Button>
              </Stack.Item>
              <Stack.Item>
                <Button
                  icon="play"
                  onClick={() => act('play_without_echo')}
                >
                  Play without echo
                </Button>
              </Stack.Item>
              <Stack.Item>
                <Button
                  icon="stop"
                  color="red"
                  onClick={() => act('stop')}
                >
                  Stop
                </Button>
              </Stack.Item>
              <Stack.Item grow>
                <Box color="label">Only you hear the preview. Close this window to stop it.</Box>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
}
