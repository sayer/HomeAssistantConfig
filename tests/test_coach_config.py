"""Full offline config/template regression suite; does not connect to coach services."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from datetime import timedelta

import yaml
from homeassistant.core import HomeAssistant
from homeassistant.helpers import template
from homeassistant.util import dt as dt_util

ROOT = Path(__file__).resolve().parents[1]

class ConfigLoader(yaml.SafeLoader):
    pass
ConfigLoader.add_multi_constructor('!', lambda loader, tag, node: loader.construct_scalar(node))

class CoachConfigTests(unittest.IsolatedAsyncioTestCase):
    @classmethod
    def setUpClass(cls):
        cls.rendered = {}
        for year in (2017, 2020, 2023):
            with tempfile.TemporaryDirectory() as target:
                shutil.copy(ROOT/'configuration.template.yaml', target)
                subprocess.run(['bash',str(ROOT/'update_config.sh'),str(year),target],check=True,capture_output=True,text=True)
                text=(Path(target)/'configuration.yaml').read_text()
                assert '%%' not in text, 'Unresolved model-year tokens'
                cls.rendered[year]=yaml.load(text,Loader=ConfigLoader)

    async def asyncSetUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.hass=HomeAssistant(self.temp.name)
        template.async_setup(self.hass)
        self.cfg=self.rendered[2023]

    async def asyncTearDown(self):
        await self.hass.async_stop(force=True)
        self.temp.cleanup()

    def render(self,text,**variables):
        return template.Template(text,self.hass).async_render(variables,parse_result=False).strip()

    def test_thermostat_steps_keep_fahrenheit_precision(self):
        for year,cfg in self.rendered.items():
            for climate in cfg['mqtt']['climate']:
                command=climate.get('temperature_command_template')
                if not command: continue
                temperatures=[]
                for fahrenheit in range(50,91):
                    payload=json.loads(self.render(command,value=fahrenheit,hvac_mode='heat'))
                    temperatures.append(payload['setpoint temp heat'])
                self.assertEqual(len(set(temperatures)),41,(year,climate['name']))

    def test_missing_power_is_not_zero(self):
        for sensor in self.cfg['mqtt']['sensor']:
            if sensor.get('unique_id','').startswith('coach_power_line_'):
                for value in (None,'n/a','unknown','unavailable'):
                    self.assertIn(self.render(sensor['value_template'],value_json={'rms voltage':value,'rms current':value}),('unknown','None'))
                self.assertEqual(self.render(sensor['value_template'],value_json={'rms voltage':0,'rms current':0}),'0.0')

    def test_bunk_choice_survives_restart(self):
        self.assertNotIn('initial',self.cfg['input_boolean']['has_bunk_beds'])

    def test_motor_duty_is_not_position(self):
        for year,cfg in self.rendered.items():
            for cover in cfg['mqtt']['cover']:
                if 'WINDOW_SHADE_CONTROL_STATUS' not in cover.get('state_topic',''):continue
                payload={'motor status definition':'inactive','last command definition':'toggle reverse','motor duty':50}
                self.assertNotIn(self.render(cover['value_template'],value_json=payload),('open','closed'),cover['name'])
                self.assertNotIn('position_topic',cover,'RV-C shade motor duty is not travel position')

    def test_shade_malformed_state_clears_instead_of_retaining_movement(self):
        cover=next(c for c in self.cfg['mqtt']['cover'] if 'WINDOW_SHADE_CONTROL_STATUS' in c.get('state_topic',''))
        for payload in (None, [], 'broken', {}):
            self.assertEqual(self.render(cover['value_template'],value_json=payload),'None')
        for direction,expected in [('toggle forward','opening'),('forward','opening'),('toggle reverse','closing'),('reverse','closing')]:
            self.assertEqual(self.render(cover['value_template'],value_json={'motor status definition':'active','last command definition':direction}),expected)

    def test_group_does_not_invent_partial_position(self):
        for group in self.cfg['cover']:
            for name,cover in group.get('covers',{}).items():
                if name.endswith('shades') and 'position_template' in cover:
                    self.assertIn(self.render(cover['position_template']),('None','unknown',''),name)

    def test_generator_duration_uses_timestamp(self):
        automations=yaml.safe_load((ROOT/'automations.yaml').read_text())
        stopped=next(x for x in automations if x.get('alias')=='Generator Turned Off')
        start=dt_util.now()-timedelta(seconds=3665)
        self.hass.states.async_set('input_datetime.generator_run_start',start.strftime('%Y-%m-%d %H:%M:%S'),{'timestamp':start.timestamp()})
        duration=self.render(stopped['actions'][0]['variables']['duration'])
        self.assertLess(abs(float(duration)-3665),2)

    def test_generator_unset_local_epoch_is_not_a_run(self):
        self.hass.states.async_set('input_datetime.generator_run_start','1970-01-01 00:00:00',{'timestamp':25200})
        self.hass.states.async_set('switch.generator','on')
        automations=yaml.safe_load((ROOT/'automations.yaml').read_text())
        stopped=next(x for x in automations if x.get('alias')=='Generator Turned Off')
        self.assertEqual(self.render(stopped['actions'][0]['variables']['duration']),'0')
        sensors=self.cfg['template'][0]['sensor']
        numeric=next(s for s in sensors if s.get('unique_id')=='generator_current_session')
        self.assertEqual(self.render(numeric['availability']),'False')
        display=next(s for s in sensors if s.get('unique_id')=='generator_session_display')
        self.assertIn('unavailable',self.render(display['state']))

    def test_generator_session_advances_over_minutes(self):
        self.hass.states.async_set('switch.generator','on')
        display=next(s for s in self.cfg['template'][0]['sensor'] if s.get('unique_id')=='generator_session_display')
        for seconds,expected in [(120,'0 hr 2 min'),(3665,'1 hr 1 min')]:
            start=dt_util.now()-timedelta(seconds=seconds)
            self.hass.states.async_set('input_datetime.generator_run_start',start.strftime('%Y-%m-%d %H:%M:%S'),{'timestamp':start.timestamp()})
            self.assertIn(expected,self.render(display['state']))

    def test_generator_actions_are_static_services(self):
        config=json.loads((ROOT/'.storage/lovelace.dashboard_remote').read_text())
        actions=[]
        def walk(value):
            if isinstance(value,dict):
                service=value.get('tap_action',{}).get('service','')
                if 'generator' in service:actions.append(service)
                for v in value.values():walk(v)
            elif isinstance(value,list):
                for v in value:walk(v)
        walk(config)
        self.assertTrue(actions)
        self.assertTrue(all('{{' not in action for action in actions),actions)
        self.assertIn('script.start_generator',actions)
        self.assertIn('script.stop_generator',actions)

if __name__=='__main__':unittest.main()
