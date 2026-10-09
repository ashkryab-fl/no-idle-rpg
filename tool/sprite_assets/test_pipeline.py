"""Adversarial asset checks with real ffmpeg pixels, without repository writes."""
import json
from pathlib import Path
import tempfile
import unittest

from tool.sprite_assets.pipeline import build_manifest, digest, preview_filters, run
from tool.sprite_assets.verify import verify_manifest


class AssetPipelineTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='sprite-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for color in ['red', 'blue']:
            run(['ffmpeg', '-v', 'error', '-y', '-f', 'lavfi', '-i',
                f'color=c={color}:s=8x8,format=rgba,pad=16:16:4:4:color=black@0',
                '-frames:v', '1', '-pix_fmt', 'rgba', '-update', '1', self.root/f'{color}.png'])
        run(['ffmpeg', '-v', 'error', '-y', '-i', self.root/'red.png', '-i', self.root/'blue.png',
            '-filter_complex', 'hstack=inputs=2,format=rgba', '-frames:v', '1',
            '-pix_fmt', 'rgba', '-update', '1', self.root/'source.png'])
        self.data = dict(source='source.png', size=16,
            frames=[dict(crop=[i*16,0,16,16]) for i in range(2)], output='installed.png')
        self.path = self.root/'manifest.json'
        self.save()
        build_manifest(self.path,root=self.root,previews=False)
        self.expected = {p:digest(self.root/p) for p in
            ['frames/installed_00.png','frames/installed_01.png','installed.png']}

    def save(self):
        self.path.write_text(json.dumps(self.data))

    def test_build_and_verify_reproduce_current_pngs_in_separate_output_tree(self):
        with tempfile.TemporaryDirectory(prefix='sprite-output-') as temp:
            output = Path(temp)
            build_manifest(self.path,root=self.root,output_root=output,previews=False)
            verify_manifest(self.path,root=self.root,output_root=output)
            for path, checksum in self.expected.items():
                self.assertEqual(digest(output/path),checksum)

    def test_reordered_source_rectangles_fail_even_with_unchanged_outputs(self):
        self.data['frames'][0]['crop'], self.data['frames'][1]['crop'] = (
            self.data['frames'][1]['crop'],self.data['frames'][0]['crop'])
        self.save()
        with self.assertRaisesRegex(ValueError,'does not reproduce'):
            verify_manifest(self.path,root=self.root)

    def test_atlas_cell_mismatch_is_detected(self):
        (self.root/'frames/installed_00.png').write_bytes((self.root/'frames/installed_01.png').read_bytes())
        with self.assertRaisesRegex(ValueError,'Atlas cell differs'):
            verify_manifest(self.path,root=self.root,rebuild=False)

    def test_modified_selected_source_and_shared_pose_are_rejected(self):
        run(['ffmpeg', '-v', 'error', '-y', '-i', self.root/'blue.png', '-i', self.root/'red.png',
            '-filter_complex', 'hstack=inputs=2,format=rgba', '-frames:v', '1',
            '-pix_fmt', 'rgba', '-update', '1', self.root/'source.png'])
        with self.assertRaisesRegex(ValueError,'does not reproduce'):
            verify_manifest(self.path,root=self.root)
        self.data['frames'] = [{'copy':'red.png'}, {'copy':'blue.png'}]
        self.save()
        build_manifest(self.path,root=self.root,previews=False)
        (self.root/'red.png').write_bytes((self.root/'blue.png').read_bytes())
        with self.assertRaisesRegex(ValueError,'Shared pose differs'):
            verify_manifest(self.path,root=self.root)

    def test_separate_build_uses_new_shared_pose_from_output_tree(self):
        self.data['frames'] = [{'copy':'red.png'}, {'copy':'blue.png'}]
        self.save()
        with tempfile.TemporaryDirectory(prefix='sprite-shared-output-') as temp:
            output = Path(temp)
            # A dependency was rebuilt in this output tree, not in the checkout.
            (output/'red.png').write_bytes((self.root/'blue.png').read_bytes())
            build_manifest(self.path,root=self.root,output_root=output,previews=False)
            verify_manifest(self.path,root=self.root,output_root=output)
            self.assertEqual((output/'frames/installed_00.png').read_bytes(),
                (output/'red.png').read_bytes())

    def test_invalid_translation_and_output_traversal_fail_before_build(self):
        self.data['frames'][0]['offset']=[1,0]
        self.save()
        with self.assertRaisesRegex(ValueError,'Translation exceeds'):
            build_manifest(self.path,root=self.root,previews=False)
        self.data['frames'][0]['offset']=[0,0]
        self.data['output']='../outside.png'
        self.save()
        with self.assertRaisesRegex(ValueError,'within the asset root'):
            build_manifest(self.path,root=self.root,previews=False)

    def test_world_scale_uses_full_canvas_and_actor_anchor(self):
        rig=dict(anchor=[.62,.875],worldUnitsPerPixel=.20,scaleMultiplier=1)
        preview=dict(canvas=[512,512],rig=dict(anchor=[.5,.875],worldUnitsPerPixel=.25,scaleMultiplier=1.05))
        self.assertEqual(preview_filters([512,512],rig,preview),
            'scale=390:390:flags=lanczos,pad=512:512:14:107:color=black@0,format=rgba')


if __name__ == '__main__':
    unittest.main()
