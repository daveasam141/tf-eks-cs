"""
Simple Python Flask Application
A basic REST API for CI/CD learning purposes
"""

from flask import Flask, jsonify, request
import os
import sys

app = Flask(__name__)

# Get version from environment variable (set during build)
VERSION = os.getenv('APP_VERSION', '1.0.0')
HOSTNAME = os.getenv('HOSTNAME', 'unknown')

@app.route('/')
def home():
    """Root endpoint - returns API information"""
    return jsonify({
        'message': 'Welcome to the CI/CD Learning App',
        'version': VERSION,
        'hostname': HOSTNAME,
        'status': 'healthy'
    }), 200

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'version': VERSION
    }), 200

@app.route('/api/hello', methods=['GET'])
def hello():
    """Simple hello endpoint"""
    name = request.args.get('name', 'World')
    return jsonify({
        'message': f'Hello, {name}!',
        'version': VERSION
    }), 200

@app.route('/api/echo', methods=['POST'])
def echo():
    """Echo endpoint - returns the request body"""
    data = request.get_json() or {}
    return jsonify({
        'echo': data,
        'version': VERSION
    }), 200

@app.route('/api/info')
def info():
    """System information endpoint"""
    return jsonify({
        'version': VERSION,
        'hostname': HOSTNAME,
        'python_version': sys.version.split()[0],
        'environment': os.getenv('ENVIRONMENT', 'development')
    }), 200

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)

