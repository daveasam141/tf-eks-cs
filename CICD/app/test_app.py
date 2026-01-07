"""
Unit tests for the Flask application
"""

import unittest
import os
import sys
from app import app

class TestApp(unittest.TestCase):
    """Test cases for the Flask application"""

    def setUp(self):
        """Set up test client"""
        self.app = app.test_client()
        self.app.testing = True
        os.environ['APP_VERSION'] = '1.0.0-test'
        os.environ['HOSTNAME'] = 'test-host'

    def test_home_endpoint(self):
        """Test root endpoint"""
        response = self.app.get('/')
        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertIn('message', data)
        self.assertIn('version', data)
        self.assertIn('status', data)
        self.assertEqual(data['status'], 'healthy')

    def test_health_endpoint(self):
        """Test health check endpoint"""
        response = self.app.get('/health')
        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertEqual(data['status'], 'healthy')
        self.assertIn('version', data)

    def test_hello_endpoint_default(self):
        """Test hello endpoint with default name"""
        response = self.app.get('/api/hello')
        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertIn('message', data)
        self.assertIn('Hello, World!', data['message'])

    def test_hello_endpoint_with_name(self):
        """Test hello endpoint with custom name"""
        response = self.app.get('/api/hello?name=TestUser')
        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertIn('message', data)
        self.assertIn('TestUser', data['message'])

    def test_echo_endpoint(self):
        """Test echo endpoint"""
        test_data = {'key': 'value', 'number': 123}
        response = self.app.post('/api/echo', json=test_data)
        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertIn('echo', data)
        self.assertEqual(data['echo'], test_data)

    def test_echo_endpoint_empty(self):
        """Test echo endpoint with empty body"""
        response = self.app.post('/api/echo')
        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertIn('echo', data)
        self.assertEqual(data['echo'], {})

    def test_info_endpoint(self):
        """Test info endpoint"""
        response = self.app.get('/api/info')
        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertIn('version', data)
        self.assertIn('hostname', data)
        self.assertIn('python_version', data)

if __name__ == '__main__':
    unittest.main()

